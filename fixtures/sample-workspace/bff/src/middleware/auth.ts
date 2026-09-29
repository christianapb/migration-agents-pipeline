import type { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";
import { AppError } from "../errors";

const SECRET = process.env.JWT_SECRET ?? "dev-secret";

export interface AuthedRequest extends Request {
  userId?: string;
}

export function requireAuth(req: AuthedRequest, _res: Response, next: NextFunction) {
  const header = req.headers.authorization ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!token) return next(new AppError(401, "UNAUTHENTICATED", "Missing bearer token"));
  try {
    const payload = jwt.verify(token, SECRET) as { sub: string };
    req.userId = payload.sub;
    next();
  } catch {
    next(new AppError(401, "TOKEN_EXPIRED", "Token invalid or expired"));
  }
}
