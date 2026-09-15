import { Response } from "express";
import { prisma } from "../config/postgres.js";
import { AuthedRequest } from "../middleware/auth.js";
import Message from "../models/Message.js";
import Conversation from "../models/Conversation.js";
import LiveSession from "../models/LiveSession.js";
import Story from "../models/Story.js";

export async function getStats(req: AuthedRequest, res: Response) {
  const [userCount, verifiedCount, messageCount, conversationCount, activeLiveCount, activeStoryCount] =
    await Promise.all([
      prisma.user.count().catch(() => 0),
      prisma.user.count({ where: { isEmailVerified: true } }).catch(() => 0),
      Message.countDocuments().catch(() => 0),
      Conversation.countDocuments().catch(() => 0),
      LiveSession.countDocuments({ status: "live" }).catch(() => 0),
      Story.countDocuments({ expiresAt: { $gt: new Date() } }).catch(() => 0)
    ]);

  return res.json({
    userCount,
    verifiedCount,
    messageCount,
    conversationCount,
    activeLiveCount,
    activeStoryCount
  });
}

export async function listUsers(req: AuthedRequest, res: Response) {
  const page = Math.max(1, Number(req.query.page || 1));
  const pageSize = 30;

  const users = await prisma.user.findMany({
    orderBy: { createdAt: "desc" },
    skip: (page - 1) * pageSize,
    take: pageSize,
    select: {
      id: true,
      username: true,
      email: true,
      isAdmin: true,
      isPremium: true,
      isEmailVerified: true,
      walletBalance: true,
      createdAt: true
    }
  });

  const total = await prisma.user.count();

  return res.json({ users, total, page, pageSize });
}

export async function setPremium(req: AuthedRequest, res: Response) {
  const { userId } = req.params;
  const { isPremium } = req.body;

  if (typeof isPremium !== "boolean") {
    return res.status(400).json({ error: "invalid_payload" });
  }

  const user = await prisma.user.update({
    where: { id: userId },
    data: { isPremium }
  });

  return res.json({ id: user.id, isPremium: user.isPremium });
}
