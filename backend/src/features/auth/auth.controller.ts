import { Request, Response } from "express";
import { authService } from "./auth.service";
import { AuthRequest } from "../../middleware/auth.middleware";

/**
 * Helper to extract client device name and IP address safely behind Render/Cloudflare proxies
 */
const getClientInfo = (req: Request) => {
  const rawDevice = req.headers["x-device-name"] || req.headers["user-agent"];
  const rawIp = req.headers["x-forwarded-for"] || req.ip;

  const deviceName = Array.isArray(rawDevice)
    ? rawDevice[0] ?? "Unknown Device"
    : rawDevice || "Unknown Device";

  let ipStr = Array.isArray(rawIp) ? rawIp[0] : rawIp;

  if (typeof ipStr === "string" && ipStr.includes(",")) {
    const firstIp = ipStr.split(",")[0];
    ipStr = firstIp ? firstIp.trim() : undefined;
  }

  return { deviceName, ipAddress: ipStr || undefined };
};

export const register = async (req: Request, res: Response) => {
  try {
    const body = req.body || {};
    const { deviceName, ipAddress } = getClientInfo(req);

    const result = await authService.register({
      ...body,
      deviceName,
      ipAddress,
    });

    res.status(201).json(result);
  } catch (error: any) {
    res.status(400).json({ error: error.message || "Registration failed" });
  }
};

export const login = async (req: Request, res: Response) => {
  try {
    const body = req.body || {};
    const { deviceName, ipAddress } = getClientInfo(req);

    const result = await authService.login({
      ...body,
      deviceName,
      ipAddress,
    });

    res.json(result);
  } catch (error: any) {
    res.status(401).json({ error: error.message || "Invalid credentials" });
  }
};

export const me = async (req: AuthRequest, res: Response) => {
  try {
    const user = await authService.getCurrentUser(req.user?.id);
    res.json(user);
  } catch (error: any) {
    res.status(401).json({ error: error.message || "Unauthorized" });
  }
};

export const logout = async (req: AuthRequest, res: Response) => {
  try {
    if (req.token) {
      await authService.logout(req.token);
    }
    res.json({ message: "Logged out successfully" });
  } catch (error: any) {
    res.status(500).json({ error: error.message || "Logout failed" });
  }
};

export const changePassword = async (req: AuthRequest, res: Response) => {
  try {
    const { currentPassword, newPassword } = req.body || {};
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ error: "Current and new password are required" });
    }

    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const result = await authService.changePassword(
      userId,
      currentPassword,
      newPassword,
      req.token
    );
    res.json(result);
  } catch (error: any) {
    res.status(400).json({ error: error.message || "Password change failed" });
  }
};

export const verifyPassword = async (req: AuthRequest, res: Response) => {
  try {
    const { currentPassword } = req.body || {};
    if (!currentPassword) {
      return res.status(400).json({ error: "Current password is required" });
    }

    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const isValid = await authService.verifyPassword(userId, currentPassword);
    res.json({ valid: isValid });
  } catch (error: any) {
    res.status(400).json({ valid: false, error: error.message || "Password verification failed" });
  }
};

// --- ACTIVE SESSION MANAGEMENT ---

export const getSessions = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.id;
    const currentToken = req.token;

    if (!userId || !currentToken) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const sessions = await authService.getActiveSessions(userId, currentToken);
    res.json({ sessions });
  } catch (error: any) {
    res.status(500).json({ error: error.message || "Failed to retrieve sessions" });
  }
};

export const revokeSession = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.id;
    const { id } = req.params;

    if (!userId) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    if (!id || typeof id !== "string") {
      return res.status(400).json({ error: "Session ID parameter is required" });
    }

    const sessionId = parseInt(id, 10);
    if (isNaN(sessionId)) {
      return res.status(400).json({ error: "Invalid session ID" });
    }

    const revoked = await authService.revokeSessionById(userId, sessionId);
    if (!revoked) {
      return res.status(404).json({ error: "Session not found or already terminated" });
    }

    res.json({ message: "Session revoked successfully" });
  } catch (error: any) {
    res.status(500).json({ error: error.message || "Failed to revoke session" });
  }
};

export const terminateOtherSessions = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.id;
    const currentToken = req.token;

    if (!userId || !currentToken) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const count = await authService.terminateOtherSessions(userId, currentToken);
    res.json({ message: `Terminated ${count} other active session(s)` });
  } catch (error: any) {
    res.status(500).json({ error: error.message || "Failed to terminate sessions" });
  }
};