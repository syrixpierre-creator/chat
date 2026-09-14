import { Response } from "express";
import ChatFolder from "../models/ChatFolder.js";
import { AuthedRequest } from "../middleware/auth.js";

export async function listFolders(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const folders = await ChatFolder.find({ userId }).sort({ createdAt: 1 }).lean();
  return res.json(folders);
}

export async function createFolder(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const name = ((req.body?.name as string) || "").trim();
  if (!name) {
    return res.status(400).json({ error: "invalid_payload" });
  }

  const folder = await ChatFolder.create({ userId, name, conversationIds: [] });
  return res.status(201).json(folder);
}

export async function renameFolder(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { folderId } = req.params;
  const name = ((req.body?.name as string) || "").trim();
  if (!name) {
    return res.status(400).json({ error: "invalid_payload" });
  }

  const folder = await ChatFolder.findOne({ _id: folderId, userId });
  if (!folder) {
    return res.status(404).json({ error: "not_found" });
  }

  folder.name = name;
  await folder.save();

  return res.json(folder);
}

export async function deleteFolder(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { folderId } = req.params;

  const folder = await ChatFolder.findOneAndDelete({ _id: folderId, userId });
  if (!folder) {
    return res.status(404).json({ error: "not_found" });
  }

  return res.json({ ok: true });
}

export async function toggleConversationInFolder(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { folderId, conversationId } = req.params;
  const include = req.method === "POST";

  const folder = await ChatFolder.findOne({ _id: folderId, userId });
  if (!folder) {
    return res.status(404).json({ error: "not_found" });
  }

  if (include) {
    if (!folder.conversationIds.includes(conversationId)) {
      folder.conversationIds.push(conversationId);
    }
  } else {
    folder.conversationIds = folder.conversationIds.filter((id: string) => id !== conversationId);
  }
  await folder.save();

  return res.json(folder);
}
