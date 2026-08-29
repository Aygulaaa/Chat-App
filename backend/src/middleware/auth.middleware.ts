import { Request, Response, NextFunction } from "express";
import { z, ZodError } from "zod";
import { authService } from "../features/auth/auth.service";

export interface AuthRequest extends Request {
  user?: { id: number; sessionId: number };
  token?: string;
}

/**
 * Verifies Bearer session tokens against the PostgreSQL database
 */
export const auth = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({ error: "Authentication token missing" });
  }

  const tokenParts = authHeader.split(" ");
  const token = tokenParts[1];

  if (!token || typeof token !== "string" || token.trim() === "") {
    return res.status(401).json({ error: "Malformed authentication header" });
  }

  try {
    const session = await authService.validateSessionToken(token);

    if (!session) {
      return res.status(401).json({ error: "Session invalid or expired" });
    }

    req.user = { id: session.userId, sessionId: session.sessionId };
    req.token = token;

    next();
  } catch (err) {
    console.error("Auth middleware error:", err);
    return res.status(500).json({ error: "Internal authentication error" });
  }
};

/**
 * Universal validation middleware used across all app routes
 */
export const validateData =
  (schema: z.ZodType) =>
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      await schema.parseAsync({
        body: req.body,
        query: req.query,
        params: req.params,
      });
      next();
    } catch (error) {
      if (error instanceof ZodError) {
        const issue = error.issues[0]?.message || "Invalid request payload";
        return res.status(400).json({ error: issue });
      }
      return res.status(400).json({ error: "Invalid request payload" });
    }
  };