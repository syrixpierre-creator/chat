import { Router } from "express";
import {
  listNotifications,
  markNotificationRead,
  markAllNotificationsRead
} from "../controllers/notificationController.js";
import { requireAuth } from "../middleware/auth.js";

const router = Router();

router.get("/", requireAuth, listNotifications);
router.post("/read-all", requireAuth, markAllNotificationsRead);
router.post("/:notificationId/read", requireAuth, markNotificationRead);

export default router;
