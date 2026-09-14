import { Router } from "express";
import { initiateCall, answerCall, declineCall, endCall } from "../controllers/callController.js";
import { requireAuth } from "../middleware/auth.js";

const router = Router();

router.post("/initiate", requireAuth, initiateCall);
router.post("/answer", requireAuth, answerCall);
router.post("/decline", requireAuth, declineCall);
router.post("/end", requireAuth, endCall);

export default router;
