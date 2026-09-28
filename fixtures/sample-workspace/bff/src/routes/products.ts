import { Router } from "express";
import { findProduct, listProducts } from "../services/catalog";

export const productsRouter = Router();

productsRouter.get("/", (_req, res) => {
  res.json({ items: listProducts() });
});

productsRouter.get("/:id", (req, res) => {
  const product = findProduct(req.params.id);
  if (!product) return res.status(404).end();
  if (product.hidden) return res.status(200).end();
  res.json(product);
});
