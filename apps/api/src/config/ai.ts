import bcrypt from "bcryptjs";
import { prisma } from "./postgres.js";

export const AI_BOT_USERNAME = "syrix_assistant";
const AI_BOT_EMAIL = "assistant@syrix.chat";

let cachedBotId: string | null = null;

export async function ensureAiBotUser(): Promise<string> {
  if (cachedBotId) {
    return cachedBotId;
  }

  let bot = await prisma.user.findUnique({ where: { username: AI_BOT_USERNAME } });

  if (!bot) {
    const passwordHash = await bcrypt.hash(`${Date.now()}-${Math.random()}`, 10);
    bot = await prisma.user.create({
      data: {
        username: AI_BOT_USERNAME,
        email: AI_BOT_EMAIL,
        passwordHash,
        isBot: true,
        isEmailVerified: true,
        bio: "Your SYRIX CHAT assistant. Ask me anything."
      }
    });
  }

  cachedBotId = bot.id;
  return bot.id;
}
