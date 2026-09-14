import { Response } from "express";
import crypto from "crypto";
import bcrypt from "bcryptjs";
import { prisma } from "../config/postgres.js";
import { AuthedRequest } from "../middleware/auth.js";
import { BotAuthedRequest, hashBotToken } from "../middleware/botAuth.js";
import Conversation from "../models/Conversation.js";
import Message from "../models/Message.js";
import { broadcastToUsers } from "../config/pubsub.js";

function generateBotToken() {
  return `SYRIX_BOT_${crypto.randomBytes(24).toString("hex")}`;
}

function serializeBot(bot: { id: string; name: string; tokenPrefix: string; webhookUrl: string | null; createdAt: Date; botUserId: string }) {
  return {
    id: bot.id,
    name: bot.name,
    tokenPrefix: bot.tokenPrefix,
    webhookUrl: bot.webhookUrl,
    botUserId: bot.botUserId,
    createdAt: bot.createdAt
  };
}

export async function createBot(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const name = ((req.body?.name as string) || "").trim();
  if (!name) {
    return res.status(400).json({ error: "invalid_payload" });
  }

  const suffix = crypto.randomBytes(3).toString("hex");
  const username = `bot_${name.toLowerCase().replace(/[^a-z0-9]/g, "").slice(0, 16) || "bot"}_${suffix}`;
  const passwordHash = await bcrypt.hash(`${Date.now()}-${Math.random()}`, 10);

  const botUser = await prisma.user.create({
    data: {
      username,
      email: `${username}@bots.syrix.chat`,
      passwordHash,
      isBot: true,
      isEmailVerified: true,
      bio: "Bot created by a SYRIX CHAT developer."
    }
  });

  const token = generateBotToken();
  const tokenHash = hashBotToken(token);

  const bot = await prisma.developerBot.create({
    data: {
      ownerId: userId,
      botUserId: botUser.id,
      name,
      tokenHash,
      tokenPrefix: token.slice(0, 18)
    }
  });

  return res.status(201).json({ ...serializeBot(bot), username: botUser.username, token });
}

export async function listBots(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const bots = await prisma.developerBot.findMany({ where: { ownerId: userId }, include: { botUser: true } });
  return res.json({
    bots: bots.map((bot) => ({ ...serializeBot(bot), username: bot.botUser.username }))
  });
}

export async function updateBotWebhook(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { botId } = req.params;
  const webhookUrl = (req.body?.webhookUrl as string) || null;

  const bot = await prisma.developerBot.findUnique({ where: { id: botId } });
  if (!bot || bot.ownerId !== userId) {
    return res.status(404).json({ error: "not_found" });
  }

  const updated = await prisma.developerBot.update({ where: { id: botId }, data: { webhookUrl } });
  return res.json({ webhookUrl: updated.webhookUrl });
}

export async function regenerateBotToken(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { botId } = req.params;

  const bot = await prisma.developerBot.findUnique({ where: { id: botId } });
  if (!bot || bot.ownerId !== userId) {
    return res.status(404).json({ error: "not_found" });
  }

  const token = generateBotToken();
  const tokenHash = hashBotToken(token);
  await prisma.developerBot.update({
    where: { id: botId },
    data: { tokenHash, tokenPrefix: token.slice(0, 18) }
  });

  return res.json({ token });
}

export async function deleteBot(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { botId } = req.params;

  const bot = await prisma.developerBot.findUnique({ where: { id: botId } });
  if (!bot || bot.ownerId !== userId) {
    return res.status(404).json({ error: "not_found" });
  }

  await prisma.developerBot.delete({ where: { id: botId } });
  return res.json({ ok: true });
}

export async function botSendMessage(req: BotAuthedRequest, res: Response) {
  const bot = req.bot!;
  const { conversationId, content, type } = req.body;

  if (!content) {
    return res.status(400).json({ error: "missing_content" });
  }

  const conversation = await Conversation.findById(conversationId);
  if (!conversation || !conversation.participantIds.includes(bot.botUserId)) {
    return res.status(403).json({ error: "bot_not_in_conversation" });
  }

  const message = await Message.create({
    conversationId,
    senderId: bot.botUserId,
    type: type || "text",
    content
  });

  conversation.lastMessage = { content, senderId: bot.botUserId, createdAt: message.createdAt };
  conversation.updatedAt = new Date();
  await conversation.save();

  await broadcastToUsers(conversation.participantIds, {
    id: message._id,
    conversationId,
    senderId: bot.botUserId,
    type: message.type,
    content,
    pinned: false,
    reactions: [],
    createdAt: message.createdAt
  });

  return res.status(201).json({ id: message._id });
}
