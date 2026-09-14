import { Router } from "express";
import { getStats, listUsers, setPremium } from "../controllers/adminController.js";
import { requireAuth } from "../middleware/auth.js";
import { requireAdmin } from "../middleware/admin.js";

const router = Router();

router.use(requireAuth, requireAdmin);
router.get("/stats", getStats);
router.get("/users", listUsers);
router.patch("/users/:userId/premium", setPremium);

export default router;
