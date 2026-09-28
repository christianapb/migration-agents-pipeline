import { Router } from "express";
import jwt from "jsonwebtoken";
import { z } from "zod";
import { AppError } from "../errors";
import { verifyCredentials } from "../services/identity";

const SECRET = process.env.JWT_SECRET ?? "dev-secret";
const loginSchema = z.object({ email: z.string().email(), password: z.string().min(8) });

export const authRouter = Router();

authRouter.post("/login", async (req, res, next) => {
  const parsed = loginSchema.safeParse(req.body);
  if (!parsed.success) return next(new AppError(400, "VALIDATION", "Invalid credentials payload"));
  const user = await verifyCredentials(parsed.data);
  if (!user) return next(new AppError(401, "BAD_CREDENTIALS", "Email or password incorrect"));
  const accessToken = jwt.sign({ sub: user.userId }, SECRET, { expiresIn: "15m" });
  const refreshToken = jwt.sign({ sub: user.userId, type: "refresh" }, SECRET, { expiresIn: "7d" });
  res.json({ accessToken, refreshToken });
});

authRouter.post("/refresh", (req, res, next) => {
  const { refreshToken } = req.body ?? {};
  if (!refreshToken) return next(new AppError(400, "VALIDATION", "refreshToken required"));
  try {
    const payload = jwt.verify(refreshToken, SECRET) as { sub: string; type?: string };
    if (payload.type !== "refresh") throw new Error("wrong token type");
    res.json({ accessToken: jwt.sign({ sub: payload.sub }, SECRET, { expiresIn: "15m" }) });
  } catch {
    next(new AppError(401, "TOKEN_EXPIRED", "Refresh token invalid or expired"));
  }
});
