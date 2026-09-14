import { Response } from "express";
import LiveSession from "../models/LiveSession.js";
import LiveChatMessage from "../models/LiveChatMessage.js";
import { prisma } from "../config/postgres.js";
import { AuthedRequest } from "../middleware/auth.js";
import { createLiveKitToken } from "../config/livekit.js";
import { GIFT_CATALOG } from "./giftController.js";

let reactionCounts: Record<string, number> = {};

export async function sendLiveChatMessage(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { liveId } = req.params;
  const { content } = req.body;

  if (!content || !content.trim()) {
    return res.status(400).json({ error: "empty_content" });
  }

  const live = await LiveSession.findById(liveId);
  if (!live || live.status !== "live") {
    return res.status(404).json({ error: "not_found" });
  }

  const message = await LiveChatMessage.create({
    liveId,
    senderId: userId,
    senderUsername: req.user!.username,
    content: content.trim().slice(0, 300)
  });

  return res.status(201).json({ id: message._id, createdAt: message.createdAt });
}

export async function listLiveChatMessages(req: AuthedRequest, res: Response) {
  const { liveId } = req.params;
  const since = req.query.since as string | undefined;

  const query: Record<string, unknown> = { liveId };
  if (since) {
    query.createdAt = { $gt: new Date(since) };
  }

  const messages = await LiveChatMessage.find(query).sort({ createdAt: 1 }).limit(100).lean();
  const live = await LiveSession.findById(liveId).lean();

  return res.json({
    messages,
    reactionCount: reactionCounts[liveId] || 0,
    giftTotal: live?.giftTotal || 0
  });
}

export async function sendLiveReaction(req: AuthedRequest, res: Response) {
  const { liveId } = req.params;
  reactionCounts[liveId] = (reactionCounts[liveId] || 0) + 1;
  return res.json({ ok: true, reactionCount: reactionCounts[liveId] });
}

export async function sendLiveGift(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { liveId } = req.params;
  const { giftId } = req.body;

  const gift = GIFT_CATALOG.find((g) => g.id === giftId);
  if (!gift) {
    return res.status(400).json({ error: "invalid_gift" });
  }

  const live = await LiveSession.findById(liveId);
  if (!live || live.status !== "live") {
    return res.status(404).json({ error: "not_found" });
  }

  if (live.hostId === userId) {
    return res.status(400).json({ error: "cannot_gift_self" });
  }

  const debited = await prisma.user.updateMany({
    where: { id: userId, walletBalance: { gte: gift.cost } },
    data: { walletBalance: { decrement: gift.cost } }
  });

  if (debited.count === 0) {
    return res.status(402).json({ error: "insufficient_balance", required: gift.cost });
  }

  await prisma.user.update({
    where: { id: live.hostId },
    data: { walletBalance: { increment: gift.cost } }
  });

  await prisma.walletTransaction.createMany({
    data: [
      { userId, type: "gift_sent", amount: gift.cost },
      { userId: live.hostId, type: "gift_received", amount: gift.cost }
    ]
  });

  live.giftTotal = (live.giftTotal || 0) + gift.cost;
  await live.save();

  await LiveChatMessage.create({
    liveId,
    senderId: userId,
    senderUsername: req.user!.username,
    content: `sent a ${gift.label}`
  });

  return res.status(201).json({ giftTotal: live.giftTotal, gift });
}

export async function listActiveLives(req: AuthedRequest, res: Response) {
  const lives = await LiveSession.find({ status: "live" }).sort({ startedAt: -1 }).lean();

  const hostIds = Array.from(new Set(lives.map((l) => l.hostId)));
  const users = await prisma.user.findMany({
    where: { id: { in: hostIds } },
    select: { id: true, username: true }
  });
  const usernameById = new Map(users.map((u) => [u.id, u.username]));

  return res.json(
    lives.map((live) => ({
      id: live._id,
      title: live.title,
      hostId: live.hostId,
      hostUsername: usernameById.get(live.hostId) || "Unknown",
      viewerCount: live.viewerCount,
      startedAt: live.startedAt
    }))
  );
}

export async function startLive(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { title } = req.body;

  if (!title) {
    return res.status(400).json({ error: "missing_title" });
  }

  const existing = await LiveSession.findOne({ hostId: userId, status: "live" });
  if (existing) {
    return res.status(409).json({ error: "already_live", id: existing._id });
  }

  const live = await LiveSession.create({ hostId: userId, title });
  return res.status(201).json({ id: live._id });
}

export async function endLive(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { liveId } = req.params;

  const live = await LiveSession.findOne({ _id: liveId, hostId: userId });
  if (!live) {
    return res.status(404).json({ error: "not_found" });
  }

  live.status = "ended";
  live.endedAt = new Date();
  await live.save();

  return res.json({ ok: true });
}

export async function getLiveToken(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { liveId } = req.params;

  const live = await LiveSession.findById(liveId);
  if (!live || live.status !== "live") {
    return res.status(404).json({ error: "not_found" });
  }

  const isHost = live.hostId === userId;
  const roomName = `live-${live._id}`;

  const token = await createLiveKitToken({
    roomName,
    identity: userId,
    name: req.user!.username,
    canPublish: isHost
  });

  if (!isHost) {
    await LiveSession.updateOne({ _id: liveId }, { $inc: { viewerCount: 1 } });
  }

  return res.json({
    token,
    url: process.env.LIVEKIT_URL || "ws://localhost:7880",
    roomName,
    isHost
  });
}
