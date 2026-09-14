import { prisma } from "./postgres.js";

export async function dispatchBotWebhooks(
  conversationId: string,
  participantIds: string[],
  senderId: string,
  message: Record<string, unknown>
) {
  const bots = await prisma.developerBot.findMany({
    where: { botUserId: { in: participantIds } }
  });

  await Promise.all(
    bots
      .filter((bot) => bot.webhookUrl && bot.botUserId !== senderId)
      .map(async (bot) => {
        try {
          await fetch(bot.webhookUrl as string, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ conversationId, message })
          });
        } catch (err) {
          console.error(`Webhook dispatch failed for bot ${bot.id}`, err);
        }
      })
  );
}
