import { Response } from "express";
import Message from "../models/Message.js";
import Conversation from "../models/Conversation.js";
import { AuthedRequest } from "../middleware/auth.js";
import { redisPublisher, MESSAGES_CHANNEL, broadcastToUsers } from "../config/pubsub.js";
import { ensureAiBotUser } from "../config/ai.js";
import { generateAssistantReply, translateText, moderateText } from "../config/ollama.js";
import { transcribeAudioFile } from "../config/whisper.js";
import { dispatchBotWebhooks } from "../config/botWebhook.js";
import MemberStats from "../models/MemberStats.js";
import { XP_PER_MESSAGE, XP_COOLDOWN_MS } from "../config/gamification.js";
import { prisma } from "../config/postgres.js";
import { createNotification } from "./notificationController.js";
import { UPLOADS_DIR } from "../config/upload.js";
import path from "path";

const QUICK_REACTION = "\u2764\uFE0F";

async function broadcastMessage(participantIds: string[], message: any) {
  await redisPublisher.publish(
    MESSAGES_CHANNEL,
    JSON.stringify({ participantIds, message })
  );
}

async function triggerAssistantReply(conversationId: string, botId: string) {
  const history = await Message.find({ conversationId })
    .sort({ createdAt: 1 })
    .limit(20)
    .lean();

  const chatHistory = history.map((m) => ({
    role: (m.senderId === botId ? "assistant" : "user") as "assistant" | "user",
    content: m.content || ""
  }));

  let replyText: string;
  try {
    replyText = await generateAssistantReply(chatHistory);
  } catch (err) {
    console.error("AI assistant reply failed", err);
    replyText = "Sorry, I'm having trouble responding right now. Please try again in a moment.";
  }

  if (!replyText) {
    return;
  }

  const reply = await Message.create({
    conversationId,
    senderId: botId,
    type: "text",
    content: replyText
  });

  const conversation = await Conversation.findById(conversationId);
  if (conversation) {
    conversation.lastMessage = {
      content: replyText,
      senderId: botId,
      createdAt: reply.createdAt
    };
    conversation.updatedAt = new Date();
    await conversation.save();

    await broadcastMessage(conversation.participantIds, {
      id: reply._id,
      conversationId,
      senderId: botId,
      type: reply.type,
      content: replyText,
      createdAt: reply.createdAt
    });
  }
}

export async function listMessages(req: AuthedRequest, res: Response) {
  const { conversationId } = req.params;
  const userId = req.user!.id;

  const conversation = await Conversation.findById(conversationId).lean();
  if (!conversation || !conversation.participantIds.includes(userId)) {
    return res.status(404).json({ error: "not_found" });
  }

  const messages = await Message.find({ conversationId, deletedFor: { $ne: userId } })
    .sort({ createdAt: 1 })
    .limit(200)
    .lean();

  if (conversation.unreadBy?.includes(userId)) {
    await Conversation.updateOne({ _id: conversationId }, { $pull: { unreadBy: userId } });
  }

  return res.json(messages);
}

async function chargeForMessage(
  senderId: string,
  payeeId: string,
  amount: number
): Promise<{ ok: boolean }> {
  if (senderId === payeeId || amount <= 0) {
    return { ok: true };
  }

  const debited = await prisma.user.updateMany({
    where: { id: senderId, walletBalance: { gte: amount } },
    data: { walletBalance: { decrement: amount } }
  });

  if (debited.count === 0) {
    return { ok: false };
  }

  await prisma.user.update({
    where: { id: payeeId },
    data: { walletBalance: { increment: amount } }
  });

  await prisma.walletTransaction.createMany({
    data: [
      { userId: senderId, type: "message_payment_sent", amount },
      { userId: payeeId, type: "message_payment_received", amount }
    ]
  });

  return { ok: true };
}

export async function sendMessage(req: AuthedRequest, res: Response) {
  const { conversationId } = req.params;
  const { content, type, spoiler, replyToId, durationSeconds } = req.body;
  const userId = req.user!.id;

  if (!content) {
    return res.status(400).json({ error: "missing_content" });
  }

  const conversation = await Conversation.findById(conversationId);
  if (!conversation || !conversation.participantIds.includes(userId)) {
    return res.status(404).json({ error: "not_found" });
  }

  if (
    (conversation.type === "group" || conversation.type === "community") &&
    conversation.closedGroup &&
    conversation.creatorId !== userId &&
    !conversation.adminIds.includes(userId)
  ) {
    return res.status(403).json({ error: "group_closed" });
  }

  if (
    (conversation.type === "group" || conversation.type === "community") &&
    conversation.aiModerationEnabled &&
    (type || "text") === "text"
  ) {
    try {
      const moderation = await moderateText(content);
      if (moderation.blocked) {
        return res.status(422).json({ error: "message_blocked", category: moderation.category });
      }
    } catch (err) {
      console.error("Moderation check failed, letting message through", err);
    }
  }

  if (conversation.type === "private") {
    const otherId = conversation.participantIds.find((id: string) => id !== userId);
    if (otherId) {
      const otherUser = await prisma.user.findUnique({ where: { id: otherId } });
      if (otherUser && otherUser.dmPrice > 0 && !otherUser.isBot) {
        const result = await chargeForMessage(userId, otherId, otherUser.dmPrice);
        if (!result.ok) {
          return res.status(402).json({ error: "insufficient_balance", required: otherUser.dmPrice });
        }
      }
    }
  } else if (conversation.messagePrice > 0 && conversation.creatorId) {
    const result = await chargeForMessage(userId, conversation.creatorId, conversation.messagePrice);
    if (!result.ok) {
      return res.status(402).json({ error: "insufficient_balance", required: conversation.messagePrice });
    }
  }

  let replyTo: { messageId: string; senderId: string; content: string; type: string } | undefined;
  if (replyToId) {
    const original = await Message.findOne({ _id: replyToId, conversationId }).lean();
    if (original) {
      replyTo = {
        messageId: String(original._id),
        senderId: original.senderId,
        content: original.deletedForEveryone ? "" : original.content || "",
        type: original.type
      };
    }
  }

  const expireAt =
    conversation.selfDestructSeconds > 0
      ? new Date(Date.now() + conversation.selfDestructSeconds * 1000)
      : undefined;

  const message = await Message.create({
    conversationId,
    senderId: userId,
    type: type || "text",
    content,
    spoiler: type === "image" ? Boolean(spoiler) : false,
    durationSeconds: type === "voice" ? Number(durationSeconds) || 0 : undefined,
    replyTo,
    expireAt
  });

  conversation.lastMessage = {
    content,
    senderId: userId,
    createdAt: message.createdAt
  };
  conversation.updatedAt = new Date();
  const others = conversation.participantIds.filter((id: string) => id !== userId);
  conversation.unreadBy = Array.from(new Set([...(conversation.unreadBy || []), ...others]));
  await conversation.save();

  if ((type || "text") === "text") {
    const mentionMatches = Array.from(content.matchAll(/@([a-z0-9_]{3,20})/gi)).map(
      (m: any) => m[1].toLowerCase()
    );
    if (mentionMatches.length > 0) {
      const mentionedUsers = await prisma.user.findMany({
        where: { username: { in: mentionMatches }, id: { in: others } }
      });
      for (const mentioned of mentionedUsers) {
        await createNotification({
          userId: mentioned.id,
          type: "mention",
          actorId: userId,
          conversationId,
          messageId: String(message._id),
          text: content.slice(0, 140)
        });
      }
    }
  }

  if (conversation.type === "private") {
    const otherId = conversation.participantIds.find((id: string) => id !== userId);
    if (otherId) {
      const otherUser = await prisma.user.findUnique({ where: { id: otherId } });
      const fourHoursAgo = new Date(Date.now() - 1000 * 60 * 60 * 4);
      const canAutoReply =
        !conversation.lastAutoReplyAt || conversation.lastAutoReplyAt < fourHoursAgo;
      if (otherUser?.awayEnabled && otherUser.awayMessage && canAutoReply) {
        const autoReply = await Message.create({
          conversationId,
          senderId: otherId,
          type: "text",
          content: otherUser.awayMessage
        });
        conversation.lastMessage = {
          content: otherUser.awayMessage,
          senderId: otherId,
          createdAt: autoReply.createdAt
        };
        conversation.lastAutoReplyAt = new Date();
        conversation.unreadBy = Array.from(new Set([...(conversation.unreadBy || []), userId]));
        await conversation.save();
        await broadcastMessage(conversation.participantIds, {
          id: autoReply._id,
          conversationId,
          senderId: otherId,
          type: "text",
          content: otherUser.awayMessage,
          pinned: false,
          reactions: []
        });
      }
    }
  }

  await broadcastMessage(conversation.participantIds, {
    id: message._id,
    conversationId,
    senderId: userId,
    type: message.type,
    content,
    spoiler: message.spoiler,
    durationSeconds: message.durationSeconds,
    pinned: false,
    reactions: [],
    replyTo: message.replyTo,
    expireAt: message.expireAt,
    createdAt: message.createdAt
  });

  const botId = await ensureAiBotUser();
  if (userId !== botId && conversation.participantIds.includes(botId)) {
    triggerAssistantReply(conversationId, botId).catch((err) =>
      console.error("Failed to trigger assistant reply", err)
    );
  }

  dispatchBotWebhooks(conversationId, conversation.participantIds, userId, {
    id: message._id,
    conversationId,
    senderId: userId,
    type: message.type,
    content,
    createdAt: message.createdAt
  }).catch((err) => console.error("Failed to dispatch bot webhooks", err));

  if (conversation.type === "group" || conversation.type === "community") {
    awardXp(conversationId, userId).catch((err) => console.error("Failed to award XP", err));
  }

  return res.status(201).json({ id: message._id });
}

async function awardXp(conversationId: string, userId: string) {
  const now = new Date();
  const existing = await MemberStats.findOne({ conversationId, userId });

  if (existing && existing.lastXpAt && now.getTime() - existing.lastXpAt.getTime() < XP_COOLDOWN_MS) {
    return;
  }

  await MemberStats.findOneAndUpdate(
    { conversationId, userId },
    { $inc: { xp: XP_PER_MESSAGE }, $set: { lastXpAt: now } },
    { upsert: true }
  );
}

async function loadOwnedMessage(conversationId: string, messageId: string, userId: string) {
  const conversation = await Conversation.findById(conversationId).lean();
  if (!conversation || !conversation.participantIds.includes(userId)) {
    return { conversation: null, message: null };
  }
  const message = await Message.findOne({ _id: messageId, conversationId });
  return { conversation, message };
}

export async function editMessage(req: AuthedRequest, res: Response) {
  const { conversationId, messageId } = req.params;
  const userId = req.user!.id;
  const { content } = req.body;

  if (!content || !content.trim()) {
    return res.status(400).json({ error: "empty_content" });
  }

  const { conversation, message } = await loadOwnedMessage(conversationId, messageId, userId);
  if (!conversation || !message) {
    return res.status(404).json({ error: "not_found" });
  }
  if (message.senderId !== userId) {
    return res.status(403).json({ error: "not_your_message" });
  }
  if (message.type !== "text") {
    return res.status(400).json({ error: "not_editable" });
  }

  message.content = content.trim();
  message.edited = true;
  message.editedAt = new Date();
  await message.save();

  await broadcastToUsers(conversation.participantIds, {
    messageEvent: "edit",
    conversationId,
    messageId,
    content: message.content,
    editedAt: message.editedAt
  });

  return res.json({ content: message.content, edited: true, editedAt: message.editedAt });
}

export async function togglePinMessage(req: AuthedRequest, res: Response) {
  const { conversationId, messageId } = req.params;
  const userId = req.user!.id;

  const { conversation, message } = await loadOwnedMessage(conversationId, messageId, userId);
  if (!conversation || !message) {
    return res.status(404).json({ error: "not_found" });
  }

  message.pinned = !message.pinned;
  await message.save();

  await broadcastToUsers(conversation.participantIds, {
    messageEvent: "pin",
    conversationId,
    messageId,
    pinned: message.pinned
  });

  return res.json({ pinned: message.pinned });
}

export async function listPinnedMessages(req: AuthedRequest, res: Response) {
  const { conversationId } = req.params;
  const userId = req.user!.id;

  const conversation = await Conversation.findById(conversationId).lean();
  if (!conversation || !conversation.participantIds.includes(userId)) {
    return res.status(404).json({ error: "not_found" });
  }

  const pinned = await Message.find({ conversationId, pinned: true }).sort({ createdAt: 1 }).lean();
  return res.json(pinned);
}

export async function reactToMessage(req: AuthedRequest, res: Response) {
  const { conversationId, messageId } = req.params;
  const emoji = (req.body?.emoji as string) || QUICK_REACTION;
  const userId = req.user!.id;

  const { conversation, message } = await loadOwnedMessage(conversationId, messageId, userId);
  if (!conversation || !message) {
    return res.status(404).json({ error: "not_found" });
  }

  const existingIndex = message.reactions.findIndex(
    (r: { userId: string; emoji: string }) => r.userId === userId && r.emoji === emoji
  );

  if (existingIndex >= 0) {
    message.reactions.splice(existingIndex, 1);
  } else {
    message.reactions = message.reactions.filter((r: { userId: string }) => r.userId !== userId);
    message.reactions.push({ userId, emoji });
  }
  await message.save();

  await broadcastToUsers(conversation.participantIds, {
    messageEvent: "react",
    conversationId,
    messageId,
    reactions: message.reactions
  });

  return res.json({ reactions: message.reactions });
}

export async function translateMessage(req: AuthedRequest, res: Response) {
  const { conversationId, messageId } = req.params;
  const targetLocale = (req.body?.targetLocale as string) || req.user!.locale || "en";
  const userId = req.user!.id;

  const { conversation, message } = await loadOwnedMessage(conversationId, messageId, userId);
  if (!conversation || !message || message.type !== "text" || !message.content) {
    return res.status(404).json({ error: "not_found" });
  }

  try {
    const translated = await translateText(message.content, targetLocale);
    return res.json({ translated, targetLocale });
  } catch (err) {
    console.error("Translation failed", err);
    return res.status(502).json({ error: "translation_failed" });
  }
}

export async function deleteMessage(req: AuthedRequest, res: Response) {
  const { conversationId, messageId } = req.params;
  const scope = (req.body?.scope as string) || "me";
  const userId = req.user!.id;

  const { conversation, message } = await loadOwnedMessage(conversationId, messageId, userId);
  if (!conversation || !message) {
    return res.status(404).json({ error: "not_found" });
  }

  if (scope === "everyone") {
    if (message.senderId !== userId) {
      return res.status(403).json({ error: "forbidden" });
    }
    message.deletedForEveryone = true;
    message.content = "";
    await message.save();

    await broadcastToUsers(conversation.participantIds, {
      messageEvent: "delete",
      conversationId,
      messageId,
      deletedForEveryone: true
    });

    return res.json({ deletedForEveryone: true });
  }

  if (!message.deletedFor.includes(userId)) {
    message.deletedFor.push(userId);
    await message.save();
  }

  return res.json({ deletedForMe: true });
}

export async function transcribeMessage(req: AuthedRequest, res: Response) {
  const { conversationId, messageId } = req.params;
  const userId = req.user!.id;

  const { conversation, message } = await loadOwnedMessage(conversationId, messageId, userId);
  if (!conversation || !message || message.type !== "voice" || !message.content) {
    return res.status(404).json({ error: "not_found" });
  }

  const filename = path.basename(new URL(message.content).pathname);
  const filePath = path.join(UPLOADS_DIR, filename);

  try {
    const transcript = await transcribeAudioFile(filePath);
    return res.json({ transcript });
  } catch (err) {
    console.error("Transcription failed", err);
    return res.status(502).json({ error: "transcription_failed" });
  }
}
