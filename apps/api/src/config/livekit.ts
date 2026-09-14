import { AccessToken } from "livekit-server-sdk";

export async function createLiveKitToken(options: {
  roomName: string;
  identity: string;
  name: string;
  canPublish: boolean;
}) {
  const apiKey = process.env.LIVEKIT_API_KEY || "";
  const apiSecret = process.env.LIVEKIT_API_SECRET || "";

  const token = new AccessToken(apiKey, apiSecret, {
    identity: options.identity,
    name: options.name
  });

  token.addGrant({
    room: options.roomName,
    roomJoin: true,
    canPublish: options.canPublish,
    canSubscribe: true,
    canPublishData: true
  });

  return token.toJwt();
}
