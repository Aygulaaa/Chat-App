import { Request, Response } from "express";
import { authService } from "./auth.service";
import { AuthRequest } from "../../middleware/auth.middleware";
import { getIo } from "../../config/io";

/**
 * Helper to extract client device name and IP address safely behind Render/Cloudflare proxies
 */
const getClientInfo = (req: Request) => {
  const rawDevice = req.headers["x-device-name"] || req.headers["user-agent"];

  const deviceName = (Array.isArray(rawDevice)
    ? rawDevice[0] ?? "Unknown Device"
    : rawDevice || "Unknown Device"
  )
    // Header is client controlled: strip control chars and cap the length
    .replace(/[\u0000-\u001f\u007f]/g, "")
    .trim()
    .slice(0, 120) || "Unknown Device";

  // `req.ip` already honours the `trust proxy` setting. Reading the raw
  // X-Forwarded-For header instead would let any client spoof its address.
  return { deviceName, ipAddress: req.ip || undefined };
};

/** Only surface messages we threw on purpose; hide DB/driver internals. */
const safeMessage = (error: any, fallback: string): string => {
  const msg = typeof error?.message === "string" ? error.message : "";
  const looksInternal = !msg || error?.code || /relation|column|syntax|ECONN|timeout|pg_|duplicate key/i.test(msg);
  return looksInternal ? fallback : msg;
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
    // Two simultaneous sign-ups can both pass the "is it taken" check;
    // the UNIQUE constraint on users.username is the real guard.
    if (error?.code === "23505") {
      return res.status(400).json({ error: "Username is already taken" });
    }
    const isInternal = Boolean(error?.code);
    if (isInternal) console.error("register error:", error);
    res.status(isInternal ? 500 : 400).json({ error: safeMessage(error, "Registration failed") });
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
    // Only a real credential mismatch is a 401. A DB outage must not look
    // like "wrong password" to the client.
    if (error?.message === "Invalid username or password") {
      return res.status(401).json({ error: error.message });
    }
    console.error("login error:", error);
    res.status(500).json({ error: "Login is temporarily unavailable, please try again" });
  }
};

export const me = async (req: AuthRequest, res: Response) => {
  try {
    const user = await authService.getCurrentUser(req.user?.id);
    res.json(user);
  } catch (error: any) {
    // The client logs out on 401, so reserve it for genuine auth failures.
    if (error?.message === "Not authenticated" || error?.message === "User not found") {
      return res.status(401).json({ error: error.message });
    }
    console.error("me error:", error);
    res.status(500).json({ error: "Failed to load profile" });
  }
};

export const logout = async (req: AuthRequest, res: Response) => {
  try {
    if (req.token) {
      await authService.logout(req.token);
    }
    res.json({ message: "Logged out successfully" });
  } catch (error: any) {
    res.status(500).json({ error: safeMessage(error, "Logout failed") });
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

    // Changing the password revokes every other session in the DB — also
    // drop their live sockets so those devices are signed out right away.
    try {
      const io = getIo();
      const sockets = await io.in(`user_${userId}`).fetchSockets();
      for (const s of sockets) {
        if (Number(s.data?.sessionId) !== Number(req.user?.sessionId)) {
          s.emit("session_revoked");
          s.disconnect(true);
        }
      }
    } catch (socketErr) {
      console.error("changePassword socket cleanup error:", socketErr);
    }

    res.json(result);
  } catch (error: any) {
    res.status(400).json({ error: safeMessage(error, "Password change failed") });
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
    res.status(400).json({ valid: false, error: safeMessage(error, "Password verification failed") });
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
    res.status(500).json({ error: safeMessage(error, "Failed to retrieve sessions") });
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

    const { revoked, revokedUserId } = await authService.revokeSessionById(userId, sessionId);
    if (!revoked) {
      return res.status(404).json({ error: "Session not found or already terminated" });
    }

    // Notify the revoked device to log out immediately
    if (revokedUserId != null) {
      const io = getIo();
      const socketsInRoom = await io.in(`user_${revokedUserId}`).fetchSockets();
      for (const s of socketsInRoom) {
        if (Number(s.data?.sessionId) === Number(sessionId)) {
          s.emit("session_revoked");
          s.disconnect(true);
        }
      }
      // Also tell the requesting user's other tabs/devices the session list changed
      io.to(`user_${userId}`).emit("sessions_updated");
    }

    res.json({ message: "Session revoked successfully" });
  } catch (error: any) {
    res.status(500).json({ error: safeMessage(error, "Failed to revoke session") });
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

    // Kick all other connected sockets of this user off (they'll fail next API call and auto-logout)
    if (count > 0) {
      const io = getIo();
      // The auth middleware already resolved which session this request belongs to
      const currentSessionId = req.user?.sessionId;

      const socketsInRoom = await io.in(`user_${userId}`).fetchSockets();
      for (const s of socketsInRoom) {
        if (Number(s.data?.sessionId) !== Number(currentSessionId)) {
          s.emit("session_revoked");
          s.disconnect(true);
        }
      }
      
      // Tell the requesting device its sessions list changed
      io.to(`user_${userId}`).emit('sessions_updated');
    }

    res.json({ message: `Terminated ${count} other active session(s)` });
  } catch (error: any) {
    res.status(500).json({ error: safeMessage(error, "Failed to terminate sessions") });
  }
};