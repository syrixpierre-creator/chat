import { Router } from "express";
import {
  listActiveLives,
  startLive,
  endLive,
  getLiveToken,
  sendLiveChatMessage,
  listLiveChatMessages,
  sendLiveReaction,
  sendLiveGift
} from "../controllers/liveController.js";
import { requireAuth } from "../middleware/auth.js";

const router = Router();

router.get("/", requireAuth, listActiveLives);
router.post("/start", requireAuth, startLive);
router.post("/:liveId/end", requireAuth, endLive);
router.get("/:liveId/token", requireAuth, getLiveToken);
router.post("/:liveId/chat", requireAuth, sendLiveChatMessage);
router.get("/:liveId/chat", requireAuth, listLiveChatMessages);
router.post("/:liveId/reaction", requireAuth, sendLiveReaction);
router.post("/:liveId/gift", requireAuth, sendLiveGift);

export default router;
