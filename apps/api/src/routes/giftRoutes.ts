import { Router } from "express";
import { listGifts, sendGift } from "../controllers/giftController.js";
import { requireAuth } from "../middleware/auth.js";

const router = Router();

router.get("/", requireAuth, listGifts);
router.post("/send", requireAuth, sendGift);

export default router;
