import { Response, NextFunction, Request } from "express";
import crypto from "crypto";
import { prisma } from "../config/postgres.js";

export interface BotAuthedRequest extends Request {
  bot?: Awaited<ReturnType<typeof prisma.developerBot.findUnique>>;
}

export function hashBotToken(token: string): string {
  return crypto.createHash("sha256").update(token).digest("hex");
}

export async function requireBotToken(req: BotAuthedRequest, res: Response, next: NextFunction) {
  const header = req.headers.authorization || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (!token || !token.startsWith("SYRIX_BOT_")) {
    return res.status(401).json({ error: "unauthorized" });
  }

  const tokenHash = hashBotToken(token);
  const bot = await prisma.developerBot.findFirst({ where: { tokenHash } });
  if (!bot) {
    return res.status(401).json({ error: "unauthorized" });
  }

  req.bot = bot;
  next();
}
