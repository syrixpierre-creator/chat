import { Request, Response, NextFunction } from "express";
import { verifyToken } from "../utils/token.js";
import { prisma } from "../config/postgres.js";

export interface AuthedRequest extends Request {
  user?: Awaited<ReturnType<typeof prisma.user.findUnique>>;
  sessionId?: string;
}

export async function requireAuth(req: AuthedRequest, res: Response, next: NextFunction) {
  const header = req.headers.authorization || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (!token) {
    return res.status(401).json({ error: "unauthorized" });
  }
  try {
    const payload = verifyToken(token);
    const user = await prisma.user.findUnique({ where: { id: payload.sub } });
    if (!user) {
      return res.status(401).json({ error: "unauthorized" });
    }
    if (payload.sid) {
      const session = await prisma.session.findUnique({ where: { id: payload.sid } });
      if (!session) {
        return res.status(401).json({ error: "session_revoked" });
      }
      req.sessionId = payload.sid;
    }
    req.user = user;
    next();
  } catch {
    return res.status(401).json({ error: "unauthorized" });
  }
}
