import { Request, Response } from "express";
import { prisma } from "../config/postgres.js";
import { AuthedRequest } from "../middleware/auth.js";
import { isContactOf } from "./contactController.js";

export async function searchUsers(req: AuthedRequest, res: Response) {
  const query = String(req.query.q || "").trim();
  if (!query) {
    return res.json([]);
  }

  const users = await prisma.user.findMany({
    where: {
      username: { contains: query, mode: "insensitive" },
      NOT: { id: req.user!.id }
    },
    select: { id: true, username: true, avatarUrl: true, isAdmin: true, isBot: true, isPremium: true },
    take: 20
  });

  return res.json(users);
}

export async function updateBusinessTools(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { awayEnabled, awayMessage, quickReplies } = req.body;

  const user = await prisma.user.update({
    where: { id: userId },
    data: {
      awayEnabled: typeof awayEnabled === "boolean" ? awayEnabled : undefined,
      awayMessage: typeof awayMessage === "string" ? awayMessage.slice(0, 300) : undefined,
      quickReplies: Array.isArray(quickReplies)
        ? quickReplies
            .filter((q: any) => q && typeof q.shortcut === "string" && typeof q.text === "string")
            .slice(0, 20)
            .map((q: any) => ({ shortcut: q.shortcut.slice(0, 30), text: q.text.slice(0, 500) }))
        : undefined
    }
  });

  return res.json({
    awayEnabled: user.awayEnabled,
    awayMessage: user.awayMessage,
    quickReplies: user.quickReplies
  });
}

export async function getBusinessTools(req: AuthedRequest, res: Response) {
  const user = await prisma.user.findUnique({ where: { id: req.user!.id } });
  return res.json({
    awayEnabled: user?.awayEnabled || false,
    awayMessage: user?.awayMessage || "",
    quickReplies: user?.quickReplies || []
  });
}

export async function updateProfile(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { bio, locale, profileVisibility, dmPrice, location, birthDateVisibility, storyVisibility } = req.body;

  const user = await prisma.user.update({
    where: { id: userId },
    data: {
      bio: typeof bio === "string" ? bio.slice(0, 200) : undefined,
      locale: locale === "fr" || locale === "en" ? locale : undefined,
      profileVisibility:
        profileVisibility === "contacts" || profileVisibility === "everyone"
          ? profileVisibility
          : undefined,
      birthDateVisibility:
        ["hidden", "contacts", "everyone"].includes(birthDateVisibility) ? birthDateVisibility : undefined,
      storyVisibility:
        storyVisibility === "contacts" || storyVisibility === "everyone" ? storyVisibility : undefined,
      dmPrice:
        typeof dmPrice === "number" && dmPrice >= 0 ? Math.floor(dmPrice) : undefined,
      location:
        typeof location === "string" && req.user!.isPremium ? location.slice(0, 100) : undefined
    }
  });

  return res.json({
    id: user.id,
    username: user.username,
    bio: user.bio,
    locale: user.locale,
    avatarUrl: user.avatarUrl,
    bannerUrl: user.bannerUrl,
    location: user.location,
    isPremium: user.isPremium,
    profileVisibility: user.profileVisibility,
    birthDateVisibility: user.birthDateVisibility,
    storyVisibility: user.storyVisibility,
    dmPrice: user.dmPrice
  });
}

export async function uploadBanner(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  if (!req.user!.isPremium) {
    return res.status(403).json({ error: "premium_required" });
  }
  const file = (req as any).file;
  if (!file) {
    return res.status(400).json({ error: "missing_file" });
  }
  const host = `${req.protocol}://${req.get("host")}`;
  const bannerUrl = `${host}/uploads/${file.filename}`;

  await prisma.user.update({
    where: { id: userId },
    data: { bannerUrl }
  });

  return res.status(201).json({ bannerUrl });
}

export async function uploadAvatar(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const file = (req as any).file;
  if (!file) {
    return res.status(400).json({ error: "missing_file" });
  }
  const host = `${req.protocol}://${req.get("host")}`;
  const avatarUrl = `${host}/uploads/${file.filename}`;

  await prisma.user.update({
    where: { id: userId },
    data: { avatarUrl }
  });

  return res.status(201).json({ avatarUrl });
}

export async function getNearbySuggestions(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const me = await prisma.user.findUnique({ where: { id: userId } });

  if (!me || !me.location) {
    return res.json([]);
  }

  const users = await prisma.user.findMany({
    where: {
      id: { not: userId },
      isBot: false,
      profileVisibility: "everyone",
      location: { equals: me.location, mode: "insensitive" }
    },
    select: { id: true, username: true, avatarUrl: true, isPremium: true, location: true },
    take: 20
  });

  return res.json(users);
}

export async function getPublicProfileByUsername(req: Request, res: Response) {
  const { username } = req.params;

  const user = await prisma.user.findUnique({ where: { username } });
  if (!user || user.profileVisibility !== "everyone") {
    return res.status(404).json({ error: "not_found" });
  }

  return res.json({
    username: user.username,
    avatarUrl: user.avatarUrl,
    bannerUrl: user.bannerUrl,
    bio: user.bio,
    isPremium: user.isPremium,
    isBot: user.isBot
  });
}

export async function getUserProfile(req: AuthedRequest, res: Response) {
  const viewerId = req.user!.id;
  const { userId } = req.params;

  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) {
    return res.status(404).json({ error: "not_found" });
  }

  const isSelf = user.id === viewerId;
  const isContact = await isContactOf(user.id, viewerId);
  const canViewFull = isSelf || user.profileVisibility === "everyone" || isContact;

  const canViewBirthDate =
    isSelf ||
    user.birthDateVisibility === "everyone" ||
    (user.birthDateVisibility === "contacts" && isContact);

  if (!canViewFull) {
    return res.json({
      id: user.id,
      username: user.username,
      avatarUrl: user.avatarUrl,
      isBot: user.isBot,
      isPremium: user.isPremium,
      restricted: true
    });
  }

  return res.json({
    id: user.id,
    username: user.username,
    avatarUrl: user.avatarUrl,
    bannerUrl: user.bannerUrl,
    location: user.location,
    bio: user.bio,
    isBot: user.isBot,
    isPremium: user.isPremium,
    dmPrice: user.dmPrice,
    birthDate: canViewBirthDate ? user.birthDate : null,
    restricted: false
  });
}
