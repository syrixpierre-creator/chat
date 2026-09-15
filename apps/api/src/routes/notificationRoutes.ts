import { Router } from "express";
import {
  listNotifications,
  markNotificationRead,
  markAllNotificationsRead,
  deleteNotification,
  clearAllNotifications
} from "../controllers/notificationController.js";
import { requireAuth } from "../middleware/auth.js";

const router = Router();

router.get("/", requireAuth, listNotifications);
router.post("/read-all", requireAuth, markAllNotificationsRead);
router.post("/:notificationId/read", requireAuth, markNotificationRead);
router.delete("/", requireAuth, clearAllNotifications);
router.delete("/:notificationId", requireAuth, deleteNotification);

export default router;
