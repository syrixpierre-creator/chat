import { Router } from "express";
import { uploadChatMedia } from "../controllers/uploadController.js";
import { requireAuth } from "../middleware/auth.js";
import { upload } from "../config/upload.js";

const router = Router();

router.post("/chat-media", requireAuth, upload.single("file"), uploadChatMedia);

export default router;
