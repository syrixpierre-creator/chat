import { MockRedis } from "./redis.js";

export const redisSubscriber = new MockRedis() as any;
export const redisPublisher = new MockRedis() as any;

export const MESSAGES_CHANNEL = "syrix:messages";

export async function broadcastToUsers(userIds: string[], payload: Record<string, unknown>) {
  await redisPublisher.publish(
    MESSAGES_CHANNEL,
    JSON.stringify({ participantIds: userIds, message: payload })
  );
}
