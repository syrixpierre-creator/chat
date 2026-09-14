import { Router } from "express";
import {
  listMessages,
  sendMessage,
  editMessage,
  togglePinMessage,
  listPinnedMessages,
  reactToMessage,
  translateMessage,
  deleteMessage,
  transcribeMessage
} from "../controllers/messageController.js";
import { requireAuth } from "../middleware/auth.js";

const router = Router();

router.get("/:conversationId/messages", requireAuth, listMessages);
router.post("/:conversationId/messages", requireAuth, sendMessage);
router.patch("/:conversationId/messages/:messageId", requireAuth, editMessage);
router.get("/:conversationId/messages/pinned", requireAuth, listPinnedMessages);
router.post("/:conversationId/messages/:messageId/pin", requireAuth, togglePinMessage);
router.post("/:conversationId/messages/:messageId/react", requireAuth, reactToMessage);
router.post("/:conversationId/messages/:messageId/translate", requireAuth, translateMessage);
router.post("/:conversationId/messages/:messageId/transcribe", requireAuth, transcribeMessage);
router.delete("/:conversationId/messages/:messageId", requireAuth, deleteMessage);

export default router;
