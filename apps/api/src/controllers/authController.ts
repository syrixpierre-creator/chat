import { Request, Response } from "express";
import bcrypt from "bcryptjs";
import { prisma } from "../config/postgres.js";
import { signToken } from "../utils/token.js";
import {
  generateVerificationCode,
  storeVerificationCode,
  checkVerificationCode,
  sendVerificationEmail
} from "../utils/email.js";

function describeDevice(req: Request): string {
  const ua = req.headers["user-agent"] || "";
  if (/android/i.test(ua)) return "Android";
  if (/iphone|ipad|ios/i.test(ua)) return "iOS";
  if (/windows/i.test(ua)) return "Windows";
  if (/mac os/i.test(ua)) return "macOS";
  return "Unknown device";
}

async function createSession(userId: string, req: Request) {
  const ip = (req.headers["x-forwarded-for"] as string)?.split(",")[0]?.trim() || req.socket.remoteAddress || "";
  const session = await prisma.session.create({
    data: { userId, deviceInfo: describeDevice(req), ipAddress: ip }
  });
  return session.id;
}
import { AuthedRequest } from "../middleware/auth.js";
import { ensureAiBotUser } from "../config/ai.js";
import Conversation from "../models/Conversation.js";
import Message from "../models/Message.js";

const MINIMUM_AGE = 16;

function computeAge(birthDate: Date): number {
  const now = new Date();
  let age = now.getFullYear() - birthDate.getFullYear();
  const monthDiff = now.getMonth() - birthDate.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && now.getDate() < birthDate.getDate())) {
    age--;
  }
  return age;
}

async function generateTempUsername(): Promise<string> {
  for (let attempt = 0; attempt < 10; attempt++) {
    const candidate = `user_${Math.random().toString(36).slice(2, 10)}`;
    const taken = await prisma.user.findUnique({ where: { username: candidate } });
    if (!taken) return candidate;
  }
  return `user_${Date.now()}`;
}

export async function signup(req: Request, res: Response) {
  const { email, password, locale, birthDate } = req.body;

  if (!email || !password || !birthDate) {
    return res.status(400).json({ error: "missing_fields" });
  }

  const parsedBirthDate = new Date(birthDate);
  if (Number.isNaN(parsedBirthDate.getTime())) {
    return res.status(400).json({ error: "invalid_birth_date" });
  }

  if (computeAge(parsedBirthDate) < MINIMUM_AGE) {
    return res.status(403).json({ error: "underage", minimumAge: MINIMUM_AGE });
  }

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    return res.status(409).json({ error: "user_exists" });
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const tempUsername = await generateTempUsername();

  const user = await prisma.user.create({
    data: {
      username: tempUsername,
      usernameSet: false,
      email,
      passwordHash,
      locale: locale === "fr" ? "fr" : "en",
      birthDate: parsedBirthDate
    }
  });

  const code = generateVerificationCode();
  await storeVerificationCode(email, code);
  await sendVerificationEmail(email, code);

  try {
    const botId = await ensureAiBotUser();
    const welcomeText = "Hi! I'm your SYRIX assistant. Ask me anything, anytime.";
    const conversation = await Conversation.create({
      type: "private",
      participantIds: [user.id, botId],
      lastMessage: { content: welcomeText, senderId: botId, createdAt: new Date() }
    });
    await Message.create({
      conversationId: conversation._id,
      senderId: botId,
      type: "text",
      content: welcomeText
    });
  } catch (err) {
    console.error("Failed to create welcome conversation with AI assistant", err);
  }

  return res.status(201).json({
    id: user.id,
    username: user.username,
    email: user.email,
    isEmailVerified: user.isEmailVerified
  });
}

export async function verifyEmail(req: Request, res: Response) {
  const { email, code } = req.body;

  const valid = await checkVerificationCode(email, code);
  if (!valid) {
    return res.status(400).json({ error: "invalid_or_expired_code" });
  }

  const user = await prisma.user.update({
    where: { email },
    data: { isEmailVerified: true }
  });

  const sessionId = await createSession(user.id, req);
  const token = signToken(user.id, sessionId);
  return res.json({ token, usernameSet: user.usernameSet });
}

const USERNAME_REGEX = /^[a-z0-9_]{3,20}$/;

function normalizeUsername(raw: string): string {
  return raw.trim().replace(/^@/, "").toLowerCase();
}

async function findAvailableSuggestions(base: string, count: number): Promise<string[]> {
  const year = new Date().getFullYear();
  const candidates = [
    `${base}_official`,
    `${base}_syrix`,
    `${base}${year}`,
    `real_${base}`,
    `${base}_${Math.floor(1000 + Math.random() * 9000)}`
  ];

  const suggestions: string[] = [];
  for (const candidate of candidates) {
    if (suggestions.length >= count) break;
    if (!USERNAME_REGEX.test(candidate)) continue;
    const taken = await prisma.user.findUnique({ where: { username: candidate } });
    if (!taken) suggestions.push(candidate);
  }
  return suggestions;
}

export async function checkUsername(req: AuthedRequest, res: Response) {
  const raw = String(req.body.username || "");
  const username = normalizeUsername(raw);

  if (!USERNAME_REGEX.test(username)) {
    return res.status(400).json({
      error: "invalid_format",
      available: false
    });
  }

  const existing = await prisma.user.findUnique({ where: { username } });
  const isOwnCurrentUsername = existing && existing.id === req.user!.id;

  if (!existing || isOwnCurrentUsername) {
    return res.json({ available: true, username });
  }

  const suggestions = await findAvailableSuggestions(username, 5);
  return res.json({ available: false, username, suggestions });
}

export async function setUsername(req: AuthedRequest, res: Response) {
  const raw = String(req.body.username || "");
  const username = normalizeUsername(raw);

  if (!USERNAME_REGEX.test(username)) {
    return res.status(400).json({ error: "invalid_format" });
  }

  const existing = await prisma.user.findUnique({ where: { username } });
  if (existing && existing.id !== req.user!.id) {
    const suggestions = await findAvailableSuggestions(username, 5);
    return res.status(409).json({ error: "username_taken", suggestions });
  }

  const user = await prisma.user.update({
    where: { id: req.user!.id },
    data: { username, usernameSet: true }
  });

  return res.json({ username: user.username });
}

export async function login(req: Request, res: Response) {
  const { email, password } = req.body;
  const user = await prisma.user.findUnique({ where: { email } });

  if (!user) {
    return res.status(401).json({ error: "invalid_credentials" });
  }

  const valid = await bcrypt.compare(password, user.passwordHash);
  if (!valid) {
    return res.status(401).json({ error: "invalid_credentials" });
  }

  const sessionId = await createSession(user.id, req);
  const token = signToken(user.id, sessionId);
  return res.json({
    token,
    user: {
      id: user.id,
      username: user.username,
      email: user.email,
      locale: user.locale,
      isEmailVerified: user.isEmailVerified,
      isAdmin: user.isAdmin
    }
  });
}

export async function listSessions(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const sessions = await prisma.session.findMany({
    where: { userId },
    orderBy: { lastSeenAt: "desc" }
  });

  return res.json(
    sessions.map((s) => ({
      id: s.id,
      deviceInfo: s.deviceInfo,
      ipAddress: s.ipAddress,
      createdAt: s.createdAt,
      lastSeenAt: s.lastSeenAt,
      current: s.id === req.sessionId
    }))
  );
}

export async function revokeSession(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { sessionId } = req.params;

  await prisma.session.deleteMany({ where: { id: sessionId, userId } });
  return res.json({ ok: true });
}

export async function revokeOtherSessions(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;

  await prisma.session.deleteMany({
    where: { userId, id: { not: req.sessionId || "" } }
  });
  return res.json({ ok: true });
}

export async function me(req: AuthedRequest, res: Response) {
  const user = req.user!;
  return res.json({
    id: user.id,
    username: user.username,
    email: user.email,
    locale: user.locale,
    bio: user.bio,
    avatarUrl: user.avatarUrl,
    bannerUrl: user.bannerUrl,
    location: user.location,
    isEmailVerified: user.isEmailVerified,
    usernameSet: user.usernameSet,
    isPremium: user.isPremium,
    isAdmin: user.isAdmin,
    walletBalance: user.walletBalance,
    profileVisibility: user.profileVisibility,
    birthDateVisibility: user.birthDateVisibility,
    storyVisibility: user.storyVisibility,
    dmPrice: user.dmPrice
  });
}
