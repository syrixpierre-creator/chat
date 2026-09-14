import { Router } from "express";
import { listNotes, createNote, updateNote, deleteNote } from "../controllers/noteController.js";
import { requireAuth } from "../middleware/auth.js";

const router = Router();

router.get("/", requireAuth, listNotes);
router.post("/", requireAuth, createNote);
router.patch("/:noteId", requireAuth, updateNote);
router.delete("/:noteId", requireAuth, deleteNote);

export default router;
