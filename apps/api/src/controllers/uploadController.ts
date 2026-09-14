import { Response } from "express";
import { AuthedRequest } from "../middleware/auth.js";

export async function uploadChatMedia(req: AuthedRequest, res: Response) {
  const file = (req as any).file;
  if (!file) {
    return res.status(400).json({ error: "missing_file" });
  }
  const host = `${req.protocol}://${req.get("host")}`;
  return res.status(201).json({ url: `${host}/uploads/${file.filename}` });
}
