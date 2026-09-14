import { Response } from "express";
import Message from "../models/Message.js";
import Conversation from "../models/Conversation.js";
import { AuthedRequest } from "../middleware/auth.js";
import { prisma } from "../config/postgres.js";
import { broadcastToUsers } from "../config/pubsub.js";

export const GIFT_CATALOG = [
  { id: "rose", label: "Rose", icon: "rose", cost: 50 },
  { id: "heart", label: "Heart", icon: "heart", cost: 100 },
  { id: "star", label: "Star", icon: "star", cost: 250 },
  { id: "crown", label: "Crown", icon: "crown", cost: 1000 }
];

export async function listGifts(req: AuthedRequest, res: Response) {
  return res.json(GIFT_CATALOG);
}

export async function sendGift(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { conversationId, giftId } = req.body;

  const gift = GIFT_CATALOG.find((g) => g.id === giftId);
  if (!gift) {
    return res.status(400).json({ error: "invalid_gift" });
  }

  const conversation = await Conversation.findById(conversationId);
  if (!conversation || !conversation.participantIds.includes(userId)) {
    return res.status(404).json({ error: "not_found" });
  }

  if (conversation.type !== "private") {
    return res.status(400).json({ error: "gifts_private_only" });
  }

  const recipientId = conversation.participantIds.find((id: string) => id !== userId);
  if (!recipientId) {
    return res.status(400).json({ error: "no_recipient" });
  }

  const debited = await prisma.user.updateMany({
    where: { id: userId, walletBalance: { gte: gift.cost } },
    data: { walletBalance: { decrement: gift.cost } }
  });

  if (debited.count === 0) {
    return res.status(402).json({ error: "insufficient_balance", required: gift.cost });
  }

  await prisma.user.update({
    where: { id: recipientId },
    data: { walletBalance: { increment: gift.cost } }
  });

  await prisma.walletTransaction.createMany({
    data: [
      { userId, type: "gift_sent", amount: gift.cost },
      { userId: recipientId, type: "gift_received", amount: gift.cost }
    ]
  });

  const message = await Message.create({
    conversationId,
    senderId: userId,
    type: "gift",
    content: JSON.stringify({ giftId: gift.id, label: gift.label, icon: gift.icon, cost: gift.cost })
  });

  conversation.lastMessage = {
    content: `Sent a gift: ${gift.label}`,
    senderId: userId,
    createdAt: message.createdAt
  };
  conversation.updatedAt = new Date();
  await conversation.save();

  await broadcastToUsers(conversation.participantIds, {
    id: message._id,
    conversationId,
    senderId: userId,
    type: "gift",
    content: message.content,
    createdAt: message.createdAt
  });

  return res.status(201).json({ id: message._id });
}
