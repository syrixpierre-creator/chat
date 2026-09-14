import { Router } from "express";
import {
  createBot,
  listBots,
  updateBotWebhook,
  regenerateBotToken,
  deleteBot,
  botSendMessage
} from "../controllers/botController.js";
import { requireAuth } from "../middleware/auth.js";
import { requireBotToken } from "../middleware/botAuth.js";

const router = Router();

router.get("/", requireAuth, listBots);
router.post("/", requireAuth, createBot);
router.patch("/:botId/webhook", requireAuth, updateBotWebhook);
router.post("/:botId/regenerate-token", requireAuth, regenerateBotToken);
router.delete("/:botId", requireAuth, deleteBot);
router.post("/send", requireBotToken, botSendMessage);

export default router;
