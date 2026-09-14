import { WebSocketServer, WebSocket } from "ws";
import { Server } from "http";
import { verifyToken } from "../utils/token.js";
import { redisSubscriber, MESSAGES_CHANNEL } from "../config/pubsub.js";

const connectionsByUserId = new Map<string, Set<WebSocket>>();

export function setupWebSocketServer(httpServer: Server) {
  const wss = new WebSocketServer({ server: httpServer, path: "/ws" });

  wss.on("connection", (socket, request) => {
    const url = new URL(request.url || "", "http://localhost");
    const token = url.searchParams.get("token");

    let userId: string;
    try {
      const payload = verifyToken(token || "");
      userId = payload.sub;
    } catch {
      socket.close(4001, "unauthorized");
      return;
    }

    if (!connectionsByUserId.has(userId)) {
      connectionsByUserId.set(userId, new Set());
    }
    connectionsByUserId.get(userId)!.add(socket);

    socket.on("close", () => {
      connectionsByUserId.get(userId)?.delete(socket);
    });
  });

  redisSubscriber.subscribe(MESSAGES_CHANNEL);
  redisSubscriber.on("message", (_channel, raw) => {
    const payload = JSON.parse(raw);
    const recipientIds: string[] = payload.participantIds || [];
    for (const recipientId of recipientIds) {
      const sockets = connectionsByUserId.get(recipientId);
      if (!sockets) continue;
      for (const socket of sockets) {
        if (socket.readyState === WebSocket.OPEN) {
          socket.send(JSON.stringify(payload.message));
        }
      }
    }
  });

  return wss;
}
