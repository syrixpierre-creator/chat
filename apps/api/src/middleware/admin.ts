import { Response, NextFunction } from "express";
import { AuthedRequest } from "./auth.js";

export function requireAdmin(req: AuthedRequest, res: Response, next: NextFunction) {
  if (!req.user?.isAdmin) {
    return res.status(403).json({ error: "forbidden" });
  }
  next();
}
