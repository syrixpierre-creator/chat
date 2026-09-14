import { Request, Response } from "express";
import bcrypt from "bcryptjs";
import { prisma } from "../config/postgres.js";
import { signToken } from "../utils/token.js";
import { AuthedRequest } from "../middleware/auth.js";

export async function getSetupStatus(req: Request, res: Response) {
  const adminCount = await prisma.user.count({ where: { isAdmin: true } });
  const config = await prisma.appConfig.findUnique({ where: { id: 1 } });

  return res.json({
    adminCreated: adminCount > 0,
    domainConfigured: Boolean(config?.domain),
    domain: config?.domain || null,
    siteName: config?.siteName || "SYRIX CHAT"
  });
}

export async function initAdmin(req: Request, res: Response) {
  const adminCount = await prisma.user.count({ where: { isAdmin: true } });
  if (adminCount > 0) {
    return res.status(409).json({ error: "already_initialized" });
  }

  const { username, email, password } = req.body;
  if (!username || !email || !password) {
    return res.status(400).json({ error: "missing_fields" });
  }

  const existing = await prisma.user.findFirst({ where: { OR: [{ email }, { username }] } });
  if (existing) {
    return res.status(409).json({ error: "user_exists" });
  }

  const passwordHash = await bcrypt.hash(password, 10);

  const admin = await prisma.user.create({
    data: {
      username,
      email,
      passwordHash,
      isAdmin: true,
      isEmailVerified: true
    }
  });

  const token = signToken(admin.id);
  return res.status(201).json({ token });
}

export async function setDomain(req: AuthedRequest, res: Response) {
  const { domain, siteName } = req.body;

  if (!domain) {
    return res.status(400).json({ error: "missing_domain" });
  }

  const config = await prisma.appConfig.upsert({
    where: { id: 1 },
    update: { domain, siteName: siteName || undefined },
    create: { id: 1, domain, siteName: siteName || "SYRIX CHAT" }
  });

  return res.json(config);
}
