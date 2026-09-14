import jwt from "jsonwebtoken";

export function signToken(userId: string, sessionId?: string) {
  return jwt.sign({ sub: userId, sid: sessionId }, process.env.JWT_SECRET as string, {
    expiresIn: process.env.JWT_EXPIRES_IN || "7d"
  });
}

export function verifyToken(token: string) {
  return jwt.verify(token, process.env.JWT_SECRET as string) as { sub: string; sid?: string };
}
