import { Router } from "express";
import {
  signup,
  login,
  verifyEmail,
  me,
  checkUsername,
  setUsername,
  listSessions,
  revokeSession,
  revokeOtherSessions
} from "../controllers/authController.js";
import { requireAuth } from "../middleware/auth.js";

const router = Router();

router.post("/signup", signup);
router.post("/login", login);
router.post("/verify-email", verifyEmail);
router.get("/me", requireAuth, me);
router.post("/check-username", requireAuth, checkUsername);
router.post("/set-username", requireAuth, setUsername);
router.get("/sessions", requireAuth, listSessions);
router.delete("/sessions/:sessionId", requireAuth, revokeSession);
router.post("/sessions/revoke-others", requireAuth, revokeOtherSessions);

export default router;
