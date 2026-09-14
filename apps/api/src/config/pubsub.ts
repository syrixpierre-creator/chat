import Redis from "ioredis";

export const redisSubscriber = new Redis(process.env.REDIS_URL || "redis://localhost:6379");
export const redisPublisher = new Redis(process.env.REDIS_URL || "redis://localhost:6379");

export const MESSAGES_CHANNEL = "syrix:messages";

export async function broadcastToUsers(userIds: string[], payload: Record<string, unknown>) {
  await redisPublisher.publish(
    MESSAGES_CHANNEL,
    JSON.stringify({ participantIds: userIds, message: payload })
  );
}
