import { Router } from "express";
import {
  listFolders,
  createFolder,
  renameFolder,
  deleteFolder,
  toggleConversationInFolder
} from "../controllers/folderController.js";
import { requireAuth } from "../middleware/auth.js";

const router = Router();

router.get("/", requireAuth, listFolders);
router.post("/", requireAuth, createFolder);
router.patch("/:folderId", requireAuth, renameFolder);
router.delete("/:folderId", requireAuth, deleteFolder);
router.post("/:folderId/conversations/:conversationId", requireAuth, toggleConversationInFolder);
router.delete("/:folderId/conversations/:conversationId", requireAuth, toggleConversationInFolder);

export default router;
