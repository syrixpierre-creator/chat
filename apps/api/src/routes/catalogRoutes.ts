import { Router } from "express";
import { listCatalog, createProduct, updateProduct, deleteProduct } from "../controllers/catalogController.js";
import { requireAuth } from "../middleware/auth.js";

const router = Router();

router.get("/:userId", requireAuth, listCatalog);
router.post("/", requireAuth, createProduct);
router.patch("/:productId", requireAuth, updateProduct);
router.delete("/:productId", requireAuth, deleteProduct);

export default router;
