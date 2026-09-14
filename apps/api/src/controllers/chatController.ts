import { Response } from "express";
import crypto from "crypto";
import Conversation from "../models/Conversation.js";
import AuditLog from "../models/AuditLog.js";
import { prisma } from "../config/postgres.js";
import { AuthedRequest } from "../middleware/auth.js";
import { broadcastToUsers } from "../config/pubsub.js";
import MemberStats from "../models/MemberStats.js";
import { levelFromXp, badgeForLevel } from "../config/gamification.js";

function generateInviteCode(): string {
  return crypto.randomBytes(6).toString("hex");
}

export async function listConversations(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;

  const conversations = await Conversation.find({
    participantIds: userId,
    archivedBy: { $ne: userId },
    $or: [{ communityId: { $exists: false } }, { communityId: null }]
  })
    .sort({ updatedAt: -1 })
    .lean();

  const otherIds = new Set<string>();
  for (const conv of conversations) {
    if (conv.type === "private") {
      for (const id of conv.participantIds) {
        if (id !== userId) otherIds.add(id);
      }
    }
  }

  const otherUsers = await prisma.user.findMany({
    where: { id: { in: Array.from(otherIds) } },
    select: { id: true, username: true, avatarUrl: true, isBot: true, isPremium: true }
  });
  const usernameById = new Map(otherUsers.map((u) => [u.id, u.username]));
  const avatarById = new Map(otherUsers.map((u) => [u.id, u.avatarUrl]));
  const isBotById = new Map(otherUsers.map((u) => [u.id, u.isBot]));
  const isPremiumById = new Map(otherUsers.map((u) => [u.id, u.isPremium]));

  const result = conversations.map((conv) => {
    let displayName = conv.name || "Group";
    let avatarUrl: string | null = conv.avatarUrl || null;
    let isBot = false;
    let isPremium = false;
    if (conv.type === "private") {
      const otherId = conv.participantIds.find((id: string) => id !== userId);
      displayName = (otherId && usernameById.get(otherId)) || "Unknown";
      avatarUrl = (otherId && avatarById.get(otherId)) || null;
      isBot = (otherId && isBotById.get(otherId)) || false;
      isPremium = (otherId && isPremiumById.get(otherId)) || false;
    }
    return {
      id: conv._id,
      type: conv.type,
      name: displayName,
      avatarUrl,
      isBot,
      isPremium,
      unread: (conv.unreadBy || []).includes(userId),
      lastMessage: conv.lastMessage || null,
      updatedAt: conv.updatedAt
    };
  });

  result.sort((a, b) => (b.isBot ? 1 : 0) - (a.isBot ? 1 : 0));

  return res.json(result);
}

export async function startPrivateConversation(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { targetUserId } = req.body;

  if (!targetUserId) {
    return res.status(400).json({ error: "missing_target" });
  }

  const existing = await Conversation.findOne({
    type: "private",
    participantIds: { $all: [userId, targetUserId], $size: 2 }
  });

  if (existing) {
    return res.json({ id: existing._id });
  }

  const conversation = await Conversation.create({
    type: "private",
    participantIds: [userId, targetUserId],
    creatorId: userId
  });

  return res.status(201).json({ id: conversation._id });
}

export async function archiveConversation(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { conversationId } = req.params;

  const conversation = await Conversation.findById(conversationId);
  if (!conversation || !conversation.participantIds.includes(userId)) {
    return res.status(404).json({ error: "not_found" });
  }

  await Conversation.updateOne({ _id: conversationId }, { $addToSet: { archivedBy: userId } });
  return res.json({ ok: true });
}

export async function unarchiveConversation(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { conversationId } = req.params;

  await Conversation.updateOne({ _id: conversationId }, { $pull: { archivedBy: userId } });
  return res.json({ ok: true });
}

export async function listArchivedConversations(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;

  const conversations = await Conversation.find({
    participantIds: userId,
    archivedBy: userId
  })
    .sort({ updatedAt: -1 })
    .lean();

  return res.json(
    conversations.map((c) => ({ id: c._id, type: c.type, name: c.name, updatedAt: c.updatedAt }))
  );
}

export async function createGroupOrCommunity(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { name, type, participantIds, communityId } = req.body;

  if (!name || !["group", "community"].includes(type)) {
    return res.status(400).json({ error: "invalid_payload" });
  }

  let parentCommunity = null;
  if (type === "group" && communityId) {
    parentCommunity = await Conversation.findById(communityId).lean();
    if (
      !parentCommunity ||
      parentCommunity.type !== "community" ||
      !parentCommunity.participantIds.includes(userId)
    ) {
      return res.status(400).json({ error: "invalid_community" });
    }
  }

  const uniqueParticipants = Array.from(new Set([userId, ...(participantIds || [])]));

  const conversation = await Conversation.create({
    type,
    name,
    communityId: parentCommunity ? String(parentCommunity._id) : undefined,
    participantIds: uniqueParticipants,
    creatorId: userId,
    isPrivate: true,
    inviteCode: generateInviteCode()
  });

  return res.status(201).json({ id: conversation._id });
}

export async function listCommunityGroups(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { communityId } = req.params;

  const community = await Conversation.findById(communityId).lean();
  if (!community || community.type !== "community" || !community.participantIds.includes(userId)) {
    return res.status(404).json({ error: "not_found" });
  }

  const groups = await Conversation.find({ communityId, type: "group" })
    .sort({ updatedAt: -1 })
    .lean();

  return res.json({
    community: { id: community._id, name: community.name },
    groups: groups.map((g) => ({
      id: g._id,
      name: g.name,
      memberCount: g.participantIds.length,
      updatedAt: g.updatedAt
    }))
  });
}

export async function getConversationDetails(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { conversationId } = req.params;

  const conversation = await Conversation.findById(conversationId).lean();
  if (!conversation || !conversation.participantIds.includes(userId)) {
    return res.status(404).json({ error: "not_found" });
  }

  const isCreator = conversation.creatorId === userId;

  if (conversation.type === "private") {
    const otherId = conversation.participantIds.find((id: string) => id !== userId);
    const otherUser = otherId
      ? await prisma.user.findUnique({
          where: { id: otherId },
          select: { id: true, username: true, avatarUrl: true, isBot: true, isPremium: true, dmPrice: true }
        })
      : null;

    return res.json({
      id: conversation._id,
      type: conversation.type,
      otherUser,
      selfDestructSeconds: conversation.selfDestructSeconds
    });
  }

  return res.json({
    id: conversation._id,
    type: conversation.type,
    name: conversation.name,
    avatarUrl: conversation.avatarUrl,
    description: conversation.description,
    isPrivate: conversation.isPrivate,
    messagePrice: conversation.messagePrice,
    selfDestructSeconds: conversation.selfDestructSeconds,
    aiModerationEnabled: conversation.aiModerationEnabled,
    closedGroup: conversation.closedGroup,
    inviteCode: isCreator ? conversation.inviteCode : undefined,
    isCreator,
    isAdmin: isCreator || conversation.adminIds.includes(userId),
    memberCount: conversation.participantIds.length
  });
}

export async function updateConversationSettings(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { conversationId } = req.params;
  const { name, isPrivate, messagePrice, description, avatarUrl } = req.body;

  const conversation = await Conversation.findById(conversationId);
  if (!conversation || conversation.creatorId !== userId) {
    return res.status(403).json({ error: "forbidden" });
  }

  if (typeof name === "string" && name.trim()) {
    conversation.name = name.trim();
  }
  if (typeof isPrivate === "boolean") {
    conversation.isPrivate = isPrivate;
  }
  if (typeof messagePrice === "number" && messagePrice >= 0) {
    conversation.messagePrice = Math.floor(messagePrice);
  }
  if (typeof description === "string") {
    conversation.description = description.slice(0, 300);
  }
  if (typeof avatarUrl === "string") {
    conversation.avatarUrl = avatarUrl;
  }

  await conversation.save();

  return res.json({
    id: conversation._id,
    name: conversation.name,
    isPrivate: conversation.isPrivate,
    messagePrice: conversation.messagePrice,
    description: conversation.description,
    avatarUrl: conversation.avatarUrl
  });
}

export async function uploadGroupPhoto(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { conversationId } = req.params;
  const file = (req as any).file;
  if (!file) {
    return res.status(400).json({ error: "missing_file" });
  }

  const conversation = await Conversation.findById(conversationId);
  if (!conversation || conversation.creatorId !== userId) {
    return res.status(403).json({ error: "forbidden" });
  }

  const host = `${req.protocol}://${req.get("host")}`;
  const avatarUrl = `${host}/uploads/${file.filename}`;
  conversation.avatarUrl = avatarUrl;
  await conversation.save();

  return res.status(201).json({ avatarUrl });
}

export async function updateModeration(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { conversationId } = req.params;
  const enabled = Boolean(req.body?.enabled);

  const conversation = await Conversation.findById(conversationId);
  if (!conversation || conversation.creatorId !== userId) {
    return res.status(403).json({ error: "forbidden" });
  }

  conversation.aiModerationEnabled = enabled;
  await conversation.save();

  await logAudit(conversationId, userId, enabled ? "moderation_on" : "moderation_off");

  return res.json({ aiModerationEnabled: conversation.aiModerationEnabled });
}

export async function updateSelfDestruct(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { conversationId } = req.params;
  const seconds = Number(req.body?.seconds) || 0;

  const conversation = await Conversation.findById(conversationId);
  if (!conversation || !conversation.participantIds.includes(userId)) {
    return res.status(404).json({ error: "not_found" });
  }

  conversation.selfDestructSeconds = Math.max(0, seconds);
  await conversation.save();

  await broadcastToUsers(conversation.participantIds, {
    messageEvent: "selfDestructChanged",
    conversationId,
    selfDestructSeconds: conversation.selfDestructSeconds
  });

  return res.json({ selfDestructSeconds: conversation.selfDestructSeconds });
}

export async function regenerateInviteLink(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { conversationId } = req.params;

  const conversation = await Conversation.findById(conversationId);
  if (!conversation || conversation.creatorId !== userId) {
    return res.status(403).json({ error: "forbidden" });
  }

  conversation.inviteCode = generateInviteCode();
  await conversation.save();

  return res.json({ inviteCode: conversation.inviteCode });
}

export async function joinByInviteCode(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { inviteCode } = req.params;

  const conversation = await Conversation.findOne({ inviteCode });
  if (!conversation) {
    return res.status(404).json({ error: "invalid_invite" });
  }
  if (conversation.bannedUserIds.includes(userId)) {
    return res.status(403).json({ error: "banned" });
  }

  if (!conversation.participantIds.includes(userId)) {
    conversation.participantIds.push(userId);
    await conversation.save();
  }

  return res.json({ id: conversation._id, name: conversation.name, type: conversation.type });
}

async function getUserSummaries(userIds: string[]) {
  const users = await prisma.user.findMany({ where: { id: { in: userIds } } });
  const byId = new Map(users.map((u) => [u.id, u]));
  return byId;
}

function isGroupAdmin(conversation: { creatorId?: string; adminIds: string[] }, userId: string) {
  return conversation.creatorId === userId || conversation.adminIds.includes(userId);
}

async function logAudit(
  conversationId: string,
  actorId: string,
  action:
    | "promote"
    | "demote"
    | "kick"
    | "ban"
    | "transfer_ownership"
    | "closed_group_on"
    | "closed_group_off"
    | "moderation_on"
    | "moderation_off",
  targetId?: string
) {
  await AuditLog.create({ conversationId, actorId, action, targetId });
}

export async function listMembers(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { conversationId } = req.params;

  const conversation = await Conversation.findById(conversationId).lean();
  if (!conversation || !conversation.participantIds.includes(userId)) {
    return res.status(404).json({ error: "not_found" });
  }

  const summaries = await getUserSummaries(conversation.participantIds);
  const stats = await MemberStats.find({ conversationId, userId: { $in: conversation.participantIds } }).lean();
  const statsByUser = new Map(stats.map((s) => [s.userId, s]));

  const members = conversation.participantIds.map((id: string) => {
    const user = summaries.get(id);
    const xp = statsByUser.get(id)?.xp || 0;
    const level = levelFromXp(xp);
    return {
      id,
      username: user?.username || "",
      avatarUrl: user?.avatarUrl || null,
      isBot: user?.isBot || false,
      isPremium: user?.isPremium || false,
      role: conversation.creatorId === id ? "owner" : conversation.adminIds.includes(id) ? "admin" : "member",
      xp,
      level,
      badge: badgeForLevel(level)
    };
  });

  return res.json({ members });
}

export async function getLeaderboard(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { conversationId } = req.params;

  const conversation = await Conversation.findById(conversationId).lean();
  if (!conversation || !conversation.participantIds.includes(userId)) {
    return res.status(404).json({ error: "not_found" });
  }

  const summaries = await getUserSummaries(conversation.participantIds);
  const stats = await MemberStats.find({ conversationId }).sort({ xp: -1 }).limit(50).lean();

  const leaderboard = stats.map((entry) => {
    const user = summaries.get(entry.userId);
    const level = levelFromXp(entry.xp);
    return {
      userId: entry.userId,
      username: user?.username || "",
      avatarUrl: user?.avatarUrl || null,
      xp: entry.xp,
      level,
      badge: badgeForLevel(level)
    };
  });

  return res.json({ leaderboard });
}

export async function promoteMember(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { conversationId, memberId } = req.params;

  const conversation = await Conversation.findById(conversationId);
  if (!conversation || !isGroupAdmin(conversation, userId)) {
    return res.status(403).json({ error: "forbidden" });
  }
  if (!conversation.participantIds.includes(memberId)) {
    return res.status(404).json({ error: "not_found" });
  }

  if (!conversation.adminIds.includes(memberId)) {
    conversation.adminIds.push(memberId);
    await conversation.save();
  }

  await logAudit(conversationId, userId, "promote", memberId);

  await broadcastToUsers(conversation.participantIds, {
    messageEvent: "memberUpdate",
    conversationId,
    action: "promoted",
    memberId
  });

  return res.json({ adminIds: conversation.adminIds });
}

export async function demoteMember(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { conversationId, memberId } = req.params;

  const conversation = await Conversation.findById(conversationId);
  if (!conversation || !isGroupAdmin(conversation, userId)) {
    return res.status(403).json({ error: "forbidden" });
  }
  if (memberId === conversation.creatorId) {
    return res.status(400).json({ error: "cannot_demote_owner" });
  }

  conversation.adminIds = conversation.adminIds.filter((id: string) => id !== memberId);
  await conversation.save();

  await logAudit(conversationId, userId, "demote", memberId);

  await broadcastToUsers(conversation.participantIds, {
    messageEvent: "memberUpdate",
    conversationId,
    action: "demoted",
    memberId
  });

  return res.json({ adminIds: conversation.adminIds });
}

export async function kickMember(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { conversationId, memberId } = req.params;

  const conversation = await Conversation.findById(conversationId);
  if (!conversation || !isGroupAdmin(conversation, userId)) {
    return res.status(403).json({ error: "forbidden" });
  }
  if (memberId === conversation.creatorId) {
    return res.status(400).json({ error: "cannot_kick_owner" });
  }
  if (memberId === userId) {
    return res.status(400).json({ error: "cannot_kick_self" });
  }

  const wasMember = conversation.participantIds.includes(memberId);
  conversation.participantIds = conversation.participantIds.filter((id: string) => id !== memberId);
  conversation.adminIds = conversation.adminIds.filter((id: string) => id !== memberId);
  await conversation.save();

  if (wasMember) {
    await logAudit(conversationId, userId, "kick", memberId);
    await broadcastToUsers([...conversation.participantIds, memberId], {
      messageEvent: "memberUpdate",
      conversationId,
      action: "kicked",
      memberId
    });
  }

  return res.json({ ok: true });
}

export async function banMember(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { conversationId, memberId } = req.params;

  const conversation = await Conversation.findById(conversationId);
  if (!conversation || !isGroupAdmin(conversation, userId)) {
    return res.status(403).json({ error: "forbidden" });
  }
  if (memberId === conversation.creatorId) {
    return res.status(400).json({ error: "cannot_ban_owner" });
  }
  if (memberId === userId) {
    return res.status(400).json({ error: "cannot_ban_self" });
  }

  const wasMember = conversation.participantIds.includes(memberId);
  conversation.participantIds = conversation.participantIds.filter((id: string) => id !== memberId);
  conversation.adminIds = conversation.adminIds.filter((id: string) => id !== memberId);
  if (!conversation.bannedUserIds.includes(memberId)) {
    conversation.bannedUserIds.push(memberId);
  }
  await conversation.save();

  await logAudit(conversationId, userId, "ban", memberId);

  if (wasMember) {
    await broadcastToUsers([...conversation.participantIds, memberId], {
      messageEvent: "memberUpdate",
      conversationId,
      action: "banned",
      memberId
    });
  }

  return res.json({ ok: true });
}

export async function leaveGroup(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { conversationId } = req.params;

  const conversation = await Conversation.findById(conversationId);
  if (!conversation || !conversation.participantIds.includes(userId)) {
    return res.status(404).json({ error: "not_found" });
  }
  if (userId === conversation.creatorId) {
    return res.status(400).json({ error: "owner_cannot_leave" });
  }

  conversation.participantIds = conversation.participantIds.filter((id: string) => id !== userId);
  conversation.adminIds = conversation.adminIds.filter((id: string) => id !== userId);
  await conversation.save();

  await broadcastToUsers(conversation.participantIds, {
    messageEvent: "memberUpdate",
    conversationId,
    action: "left",
    memberId: userId
  });

  return res.json({ ok: true });
}

export async function updateClosedGroup(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { conversationId } = req.params;
  const closed = Boolean(req.body?.closed);

  const conversation = await Conversation.findById(conversationId);
  if (!conversation || !isGroupAdmin(conversation, userId)) {
    return res.status(403).json({ error: "forbidden" });
  }

  conversation.closedGroup = closed;
  await conversation.save();

  await logAudit(conversationId, userId, closed ? "closed_group_on" : "closed_group_off");

  await broadcastToUsers(conversation.participantIds, {
    messageEvent: "closedGroupChanged",
    conversationId,
    closedGroup: conversation.closedGroup
  });

  return res.json({ closedGroup: conversation.closedGroup });
}

export async function transferOwnership(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { conversationId } = req.params;
  const newOwnerId = req.body?.newOwnerId as string;

  const conversation = await Conversation.findById(conversationId);
  if (!conversation || conversation.creatorId !== userId) {
    return res.status(403).json({ error: "forbidden" });
  }
  if (!newOwnerId || !conversation.participantIds.includes(newOwnerId)) {
    return res.status(400).json({ error: "invalid_new_owner" });
  }
  if (newOwnerId === userId) {
    return res.status(400).json({ error: "already_owner" });
  }

  conversation.creatorId = newOwnerId;
  conversation.adminIds = conversation.adminIds.filter((id: string) => id !== newOwnerId);
  if (!conversation.adminIds.includes(userId)) {
    conversation.adminIds.push(userId);
  }
  await conversation.save();

  await logAudit(conversationId, userId, "transfer_ownership", newOwnerId);

  await broadcastToUsers(conversation.participantIds, {
    messageEvent: "ownerTransferred",
    conversationId,
    newOwnerId,
    previousOwnerId: userId
  });

  return res.json({ creatorId: conversation.creatorId });
}

export async function getAuditLog(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { conversationId } = req.params;

  const conversation = await Conversation.findById(conversationId).lean();
  if (!conversation || !isGroupAdmin(conversation, userId)) {
    return res.status(403).json({ error: "forbidden" });
  }

  const entries = await AuditLog.find({ conversationId }).sort({ createdAt: -1 }).limit(100).lean();
  const userIds = Array.from(
    new Set(entries.flatMap((e) => [e.actorId, e.targetId]).filter((id): id is string => Boolean(id)))
  );
  const summaries = await getUserSummaries(userIds);

  const items = entries.map((entry) => ({
    id: entry._id,
    action: entry.action,
    actorUsername: summaries.get(entry.actorId)?.username || "",
    targetUsername: entry.targetId ? summaries.get(entry.targetId)?.username || "" : undefined,
    createdAt: entry.createdAt
  }));

  return res.json({ items });
}
