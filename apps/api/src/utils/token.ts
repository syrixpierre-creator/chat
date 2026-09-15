import jwt from "jsonwebtoken";

const JWT_SECRET = process.env.JWT_SECRET || "syrix_chat_jwt_secret_dev_key_2026";

export function signToken(userId: string, sessionId?: string) {
  return jwt.sign({ sub: userId, sid: sessionId }, JWT_SECRET, {
    expiresIn: (process.env.JWT_EXPIRES_IN || "7d") as any
  });
}

export function verifyToken(token: string) {
  return jwt.verify(token, JWT_SECRET) as { sub: string; sid?: string };
}
