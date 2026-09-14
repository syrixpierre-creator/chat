import { Response } from "express";
import { AuthedRequest } from "../middleware/auth.js";
import Product from "../models/Product.js";

export async function listCatalog(req: AuthedRequest, res: Response) {
  const { userId } = req.params;
  const products = await Product.find({ ownerId: userId }).sort({ createdAt: -1 }).lean();
  return res.json(products);
}

export async function createProduct(req: AuthedRequest, res: Response) {
  const ownerId = req.user!.id;
  const { name, description, price, imageUrl, launchDate } = req.body;

  if (!name) {
    return res.status(400).json({ error: "missing_name" });
  }

  const product = await Product.create({
    ownerId,
    name,
    description,
    price: Number(price) || 0,
    imageUrl,
    launchDate: launchDate ? new Date(launchDate) : undefined
  });

  return res.status(201).json(product);
}

export async function updateProduct(req: AuthedRequest, res: Response) {
  const ownerId = req.user!.id;
  const { productId } = req.params;
  const { name, description, price, imageUrl, launchDate } = req.body;

  const product = await Product.findOne({ _id: productId, ownerId });
  if (!product) {
    return res.status(404).json({ error: "not_found" });
  }

  if (name !== undefined) product.name = name;
  if (description !== undefined) product.description = description;
  if (price !== undefined) product.price = Number(price) || 0;
  if (imageUrl !== undefined) product.imageUrl = imageUrl;
  if (launchDate !== undefined) product.launchDate = new Date(launchDate);
  await product.save();

  return res.json(product);
}

export async function deleteProduct(req: AuthedRequest, res: Response) {
  const ownerId = req.user!.id;
  const { productId } = req.params;

  await Product.deleteOne({ _id: productId, ownerId });
  return res.json({ ok: true });
}
