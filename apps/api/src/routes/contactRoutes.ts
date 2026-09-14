import { Router } from "express";
import { addContact, removeContact, listContacts, renameContact } from "../controllers/contactController.js";
import { requireAuth } from "../middleware/auth.js";

const router = Router();

router.get("/", requireAuth, listContacts);
router.post("/", requireAuth, addContact);
router.patch("/:contactId", requireAuth, renameContact);
router.delete("/:contactId", requireAuth, removeContact);

export default router;
