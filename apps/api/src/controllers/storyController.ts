import { Response } from "express";
import Story from "../models/Story.js";
import { prisma } from "../config/postgres.js";
import { AuthedRequest } from "../middleware/auth.js";
import { isContactOf } from "./contactController.js";

export async function listActiveStories(req: AuthedRequest, res: Response) {
  const viewerId = req.user!.id;
  const stories = await Story.find({ expiresAt: { $gt: new Date() } })
    .sort({ createdAt: -1 })
    .lean();

  const userIds = Array.from(new Set(stories.map((s) => s.userId)));
  const users = await prisma.user.findMany({
    where: { id: { in: userIds } },
    select: { id: true, username: true, avatarUrl: true, isPremium: true, storyVisibility: true }
  });
  const usernameById = new Map(users.map((u) => [u.id, u.username]));
  const avatarById = new Map(users.map((u) => [u.id, u.avatarUrl]));
  const isPremiumById = new Map(users.map((u) => [u.id, u.isPremium]));
  const visibilityById = new Map(users.map((u) => [u.id, u.storyVisibility]));

  const allowedAuthorIds = new Set<string>();
  for (const id of userIds) {
    if (id === viewerId) {
      allowedAuthorIds.add(id);
      continue;
    }
    const visibility = visibilityById.get(id) || "everyone";
    if (visibility === "everyone" || (await isContactOf(id, viewerId))) {
      allowedAuthorIds.add(id);
    }
  }

  const grouped = new Map<
    string,
    {
      userId: string;
      username: string;
      avatarUrl: string | null;
      isPremium: boolean;
      items: (typeof stories)[number][];
    }
  >();
  for (const story of stories) {
    if (!allowedAuthorIds.has(story.userId)) continue;
    if (!grouped.has(story.userId)) {
      grouped.set(story.userId, {
        userId: story.userId,
        username: usernameById.get(story.userId) || "Unknown",
        avatarUrl: avatarById.get(story.userId) || null,
        isPremium: isPremiumById.get(story.userId) || false,
        items: []
      });
    }
    grouped.get(story.userId)!.items.push(story);
  }

  return res.json(Array.from(grouped.values()));
}

export async function uploadStoryMedia(req: AuthedRequest, res: Response) {
  const file = (req as any).file;
  if (!file) {
    return res.status(400).json({ error: "missing_file" });
  }
  const host = `${req.protocol}://${req.get("host")}`;
  return res.status(201).json({ url: `${host}/uploads/${file.filename}` });
}

export async function createStory(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { mediaUrl, caption } = req.body;

  if (!mediaUrl) {
    return res.status(400).json({ error: "missing_media" });
  }

  const story = await Story.create({
    userId,
    mediaUrl,
    caption,
    expiresAt: new Date(Date.now() + 1000 * 60 * 60 * 24)
  });

  return res.status(201).json({ id: story._id });
}

export async function markStoryViewed(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { storyId } = req.params;

  await Story.updateOne({ _id: storyId }, { $addToSet: { viewedBy: userId } });

  return res.json({ ok: true });
}

export async function repostStory(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { storyId } = req.params;

  if (!req.user!.isPremium) {
    return res.status(403).json({ error: "premium_required" });
  }

  const original = await Story.findById(storyId).lean();
  if (!original || original.expiresAt.getTime() < Date.now()) {
    return res.status(404).json({ error: "not_found" });
  }

  const originalOwner = await prisma.user.findUnique({
    where: { id: original.userId },
    select: { username: true }
  });

  const repost = await Story.create({
    userId,
    mediaUrl: original.mediaUrl,
    caption: original.caption,
    repostedFromStoryId: String(original._id),
    repostedFromUsername: originalOwner?.username || "unknown",
    expiresAt: new Date(Date.now() + 1000 * 60 * 60 * 24)
  });

  return res.status(201).json({ id: repost._id });
}
