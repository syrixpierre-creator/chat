import { Router } from "express";
import {
  listPackages,
  getBalance,
  listTransactions,
  createCheckoutSession,
  createPremiumCheckoutSession
} from "../controllers/walletController.js";
import { requireAuth } from "../middleware/auth.js";

const router = Router();

router.get("/packages", requireAuth, listPackages);
router.get("/balance", requireAuth, getBalance);
router.get("/transactions", requireAuth, listTransactions);
router.post("/checkout", requireAuth, createCheckoutSession);
router.post("/premium-checkout", requireAuth, createPremiumCheckoutSession);

export default router;
