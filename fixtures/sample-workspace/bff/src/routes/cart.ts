import { Router } from "express";
import { z } from "zod";
import { AppError } from "../errors";
import { AuthedRequest, requireAuth } from "../middleware/auth";
import { findProduct, getPriceCents } from "../services/catalog";

interface CartLine {
  productId: string;
  qty: number;
}

const carts = new Map<string, CartLine[]>();
const addSchema = z.object({ productId: z.string(), qty: z.number().int().min(1).max(10) });

export const cartRouter = Router();
cartRouter.use(requireAuth);

cartRouter.get("/", (req: AuthedRequest, res) => {
  const lines = carts.get(req.userId!) ?? [];
  const items = lines.map((l) => ({ ...l, unitPriceCents: getPriceCents(l.productId) }));
  const totalCents = items.reduce((sum, i) => sum + i.unitPriceCents * i.qty, 0);
  res.json({ items, totalCents });
});

cartRouter.post("/items", (req: AuthedRequest, res, next) => {
  const parsed = addSchema.safeParse(req.body);
  if (!parsed.success) return next(new AppError(400, "VALIDATION", "productId and qty 1-10 required"));
  const product = findProduct(parsed.data.productId);
  if (!product || product.hidden) return next(new AppError(404, "PRODUCT_NOT_FOUND", "Product not available"));
  const lines = carts.get(req.userId!) ?? [];
  const existing = lines.find((l) => l.productId === parsed.data.productId);
  if (existing) existing.qty = Math.min(10, existing.qty + parsed.data.qty);
  else lines.push(parsed.data);
  carts.set(req.userId!, lines);
  res.status(201).json({ items: lines });
});

cartRouter.delete("/items/:productId", (req: AuthedRequest, res) => {
  const lines = (carts.get(req.userId!) ?? []).filter((l) => l.productId !== req.params.productId);
  carts.set(req.userId!, lines);
  res.status(204).end();
});
