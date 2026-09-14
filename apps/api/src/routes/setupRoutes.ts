import { Router } from "express";
import { getSetupStatus, initAdmin, setDomain } from "../controllers/setupController.js";
import { requireAuth } from "../middleware/auth.js";
import { requireAdmin } from "../middleware/admin.js";

const router = Router();

router.get("/status", getSetupStatus);
router.post("/init", initAdmin);
router.post("/domain", requireAuth, requireAdmin, setDomain);

export default router;
