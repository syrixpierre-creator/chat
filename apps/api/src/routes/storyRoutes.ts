import { Router } from "express";
import {
  listActiveStories,
  createStory,
  uploadStoryMedia,
  markStoryViewed,
  repostStory
} from "../controllers/storyController.js";
import { requireAuth } from "../middleware/auth.js";
import { upload } from "../config/upload.js";

const router = Router();

router.get("/", requireAuth, listActiveStories);
router.post("/", requireAuth, createStory);
router.post("/upload", requireAuth, upload.single("file"), uploadStoryMedia);
router.post("/:storyId/view", requireAuth, markStoryViewed);
router.post("/:storyId/repost", requireAuth, repostStory);

export default router;
