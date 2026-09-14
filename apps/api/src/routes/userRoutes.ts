import { Router } from "express";
import {
  searchUsers,
  updateProfile,
  uploadAvatar,
  uploadBanner,
  getUserProfile,
  getPublicProfileByUsername,
  getNearbySuggestions,
  getBusinessTools,
  updateBusinessTools
} from "../controllers/userController.js";
import { requireAuth } from "../middleware/auth.js";
import { upload } from "../config/upload.js";

const router = Router();

router.get("/search", requireAuth, searchUsers);
router.get("/nearby", requireAuth, getNearbySuggestions);
router.get("/business-tools", requireAuth, getBusinessTools);
router.patch("/business-tools", requireAuth, updateBusinessTools);
router.get("/public/:username", getPublicProfileByUsername);
router.patch("/me", requireAuth, updateProfile);
router.post("/me/avatar", requireAuth, upload.single("file"), uploadAvatar);
router.post("/me/banner", requireAuth, upload.single("file"), uploadBanner);
router.get("/:userId/profile", requireAuth, getUserProfile);

export default router;
