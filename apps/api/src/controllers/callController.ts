import { Response } from "express";
import crypto from "crypto";
import Conversation from "../models/Conversation.js";
import { AuthedRequest } from "../middleware/auth.js";
import { createLiveKitToken } from "../config/livekit.js";
import { broadcastToUsers } from "../config/pubsub.js";

export async function initiateCall(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { conversationId, mode } = req.body;

  if (!["voice", "video"].includes(mode)) {
    return res.status(400).json({ error: "invalid_mode" });
  }

  const conversation = await Conversation.findById(conversationId);
  if (!conversation || !conversation.participantIds.includes(userId) || conversation.type !== "private") {
    return res.status(404).json({ error: "not_found" });
  }

  const otherUserId = conversation.participantIds.find((id: string) => id !== userId);
  if (!otherUserId) {
    return res.status(400).json({ error: "no_recipient" });
  }

  const roomName = `call-${crypto.randomBytes(8).toString("hex")}`;

  const token = await createLiveKitToken({
    roomName,
    identity: userId,
    name: req.user!.username,
    canPublish: true
  });

  await broadcastToUsers([otherUserId], {
    callEvent: "invite",
    roomName,
    mode,
    conversationId,
    fromUserId: userId,
    fromUsername: req.user!.username
  });

  return res.status(201).json({
    roomName,
    token,
    url: process.env.LIVEKIT_URL || "ws://localhost:7880"
  });
}

export async function answerCall(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { roomName } = req.body;

  if (!roomName) {
    return res.status(400).json({ error: "missing_room" });
  }

  const token = await createLiveKitToken({
    roomName,
    identity: userId,
    name: req.user!.username,
    canPublish: true
  });

  return res.json({
    roomName,
    token,
    url: process.env.LIVEKIT_URL || "ws://localhost:7880"
  });
}

export async function declineCall(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { roomName, toUserId } = req.body;

  if (toUserId) {
    await broadcastToUsers([toUserId], {
      callEvent: "declined",
      roomName,
      fromUserId: userId
    });
  }

  return res.json({ ok: true });
}

export async function endCall(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { roomName, toUserId } = req.body;

  if (toUserId) {
    await broadcastToUsers([toUserId], {
      callEvent: "ended",
      roomName,
      fromUserId: userId
    });
  }

  return res.json({ ok: true });
}
