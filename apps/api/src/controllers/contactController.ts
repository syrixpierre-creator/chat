import { Response } from "express";
import { prisma } from "../config/postgres.js";
import { AuthedRequest } from "../middleware/auth.js";
import { createNotification } from "./notificationController.js";

export async function addContact(req: AuthedRequest, res: Response) {
  const ownerId = req.user!.id;
  const { contactId } = req.body;

  if (!contactId || contactId === ownerId) {
    return res.status(400).json({ error: "invalid_contact" });
  }

  const targetUser = await prisma.user.findUnique({ where: { id: contactId } });
  if (!targetUser) {
    return res.status(404).json({ error: "not_found" });
  }

  await prisma.contact.upsert({
    where: { ownerId_contactId: { ownerId, contactId } },
    update: {},
    create: { ownerId, contactId }
  });

  await createNotification({ userId: contactId, type: "contact_added", actorId: ownerId });

  return res.status(201).json({ ok: true });
}

export async function removeContact(req: AuthedRequest, res: Response) {
  const ownerId = req.user!.id;
  const { contactId } = req.params;

  await prisma.contact.deleteMany({ where: { ownerId, contactId } });

  return res.json({ ok: true });
}

export async function listContacts(req: AuthedRequest, res: Response) {
  const ownerId = req.user!.id;

  const contacts = await prisma.contact.findMany({
    where: { ownerId },
    include: {
      contact: {
        select: { id: true, username: true, avatarUrl: true, bio: true }
      }
    },
    orderBy: { createdAt: "desc" }
  });

  return res.json(contacts.map((c) => ({ ...c.contact, alias: c.alias, tag: c.tag })));
}

export async function renameContact(req: AuthedRequest, res: Response) {
  const ownerId = req.user!.id;
  const { contactId } = req.params;
  const { alias, tag } = req.body;

  const data: { alias?: string | null; tag?: string | null } = {};
  if (alias !== undefined) {
    data.alias = typeof alias === "string" && alias.trim() ? alias.trim().slice(0, 50) : null;
  }
  if (tag !== undefined) {
    data.tag = typeof tag === "string" && tag.trim() ? tag.trim().slice(0, 30) : null;
  }

  const updated = await prisma.contact.updateMany({
    where: { ownerId, contactId },
    data
  });

  if (updated.count === 0) {
    return res.status(404).json({ error: "not_found" });
  }

  return res.json({ ok: true });
}

export async function isContactOf(ownerId: string, viewerId: string): Promise<boolean> {
  if (ownerId === viewerId) return true;
  const found = await prisma.contact.findUnique({
    where: { ownerId_contactId: { ownerId, contactId: viewerId } }
  });
  return Boolean(found);
}
