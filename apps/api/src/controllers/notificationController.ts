import { Response } from "express";
import { AuthedRequest } from "../middleware/auth.js";
import Notification from "../models/Notification.js";

export async function listNotifications(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;

  const notifications = await Notification.find({ userId })
    .sort({ createdAt: -1 })
    .limit(100)
    .lean();

  return res.json(notifications);
}

export async function markNotificationRead(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { notificationId } = req.params;

  await Notification.updateOne({ _id: notificationId, userId }, { read: true });
  return res.json({ ok: true });
}

export async function markAllNotificationsRead(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;

  await Notification.updateMany({ userId, read: false }, { read: true });
  return res.json({ ok: true });
}

export async function deleteNotification(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { notificationId } = req.params;

  await Notification.deleteOne({ _id: notificationId, userId });
  return res.json({ ok: true });
}

export async function clearAllNotifications(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;

  await Notification.deleteMany({ userId });
  return res.json({ ok: true });
}

export async function createNotification(params: {
  userId: string;
  type: "mention" | "contact_added" | "reaction" | "gift";
  actorId: string;
  conversationId?: string;
  messageId?: string;
  text?: string;
}) {
  if (params.userId === params.actorId) return;
  await Notification.create(params);
}
