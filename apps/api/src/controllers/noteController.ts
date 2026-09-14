import { Response } from "express";
import Note from "../models/Note.js";
import { AuthedRequest } from "../middleware/auth.js";

export async function listNotes(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const notes = await Note.find({ userId }).sort({ updatedAt: -1 }).lean();
  return res.json(notes);
}

export async function createNote(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const content = ((req.body?.content as string) || "").trim();
  if (!content) {
    return res.status(400).json({ error: "invalid_payload" });
  }

  const note = await Note.create({ userId, content });
  return res.status(201).json(note);
}

export async function updateNote(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { noteId } = req.params;
  const content = ((req.body?.content as string) || "").trim();
  if (!content) {
    return res.status(400).json({ error: "invalid_payload" });
  }

  const note = await Note.findOne({ _id: noteId, userId });
  if (!note) {
    return res.status(404).json({ error: "not_found" });
  }

  note.content = content;
  note.updatedAt = new Date();
  await note.save();

  return res.json(note);
}

export async function deleteNote(req: AuthedRequest, res: Response) {
  const userId = req.user!.id;
  const { noteId } = req.params;

  const note = await Note.findOneAndDelete({ _id: noteId, userId });
  if (!note) {
    return res.status(404).json({ error: "not_found" });
  }

  return res.json({ ok: true });
}
