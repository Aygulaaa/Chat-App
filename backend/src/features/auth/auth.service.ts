import bcrypt from "bcryptjs";
import { authRepository, UserSessionRow } from "./auth.repository";

export interface AuthInput {
  username?: string;
  password?: string;
  deviceName?: string;
  ipAddress?: string;
}

/**
 * Brute-force lockout for the login endpoint.
 *
 * After MAX_FAILED_LOGIN_ATTEMPTS consecutive failed passwords the login is
 * blocked, and the block keeps getting longer (5 min → 10 min → 60 min) on every
 * further failed attempt while it is active. A successful login clears it.
 */
export const MAX_FAILED_LOGIN_ATTEMPTS = 3;
const LOCK_DURATION_STEPS_MS = [
  5 * 60 * 1000, // first lock: 5 minutes
  10 * 60 * 1000, // second lock: 10 minutes
  60 * 60 * 1000, // third and later locks: 60 minutes
];

export class LoginLockedError extends Error {
  statusCode = 429;
  retryAfterSeconds: number;

  constructor(retryAfterSeconds: number) {
    super(
      `Too many failed login attempts. Try again in ${retryAfterSeconds} seconds.`,
    );
    this.name = "LoginLockedError";
    this.retryAfterSeconds = retryAfterSeconds;
  }
}

interface LoginLockState {
  failedAttempts: number;
  lockedUntil: number;
  lockCount: number;
}

const loginLocks = new Map<string, LoginLockState>();

const getLoginLock = (username: string): LoginLockState =>
  loginLocks.get(username) ?? {
    failedAttempts: 0,
    lockedUntil: 0,
    lockCount: 0,
  };

export interface AuthResult {
  token: string;
  user: {
    id: number;
    username: string;
  };
}

export interface SessionFormatted {
  id: number;
  deviceName: string;
  ipAddress?: string | undefined;
  lastActiveAt: Date;
  createdAt: Date;
  isCurrentDevice: boolean;
}

export const authService = {
  /**
   * Registers a new user and issues a persistent opaque session token.
   */
  async register({ username, password, deviceName, ipAddress }: AuthInput): Promise<AuthResult> {
    if (!username || !password) {
      throw new Error("Username and password are required");
    }

    const trimmedUsername = username.trim().toLowerCase();
    if (trimmedUsername.length < 3 || trimmedUsername.length > 30) {
      throw new Error("Username must be between 3 and 30 characters long");
    }

    // Protect bcrypt against Denial of Service via long passwords (bcrypt truncates at 72 bytes)
    if (password.length < 6 || password.length > 72) {
      throw new Error("Password must be between 6 and 72 characters long");
    }

    const existing = await authRepository.findByUsername(trimmedUsername);
    if (existing) {
      throw new Error("Username is already taken");
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = await authRepository.createUser(trimmedUsername, hashedPassword);

    const cleanDevice = deviceName || "Mobile Device";
    const token = await authRepository.createSession(user.id, cleanDevice, ipAddress);

    return {
      token,
      user: {
        id: user.id,
        username: user.username,
      },
    };
  },

  /**
   * Authenticates user and issues an opaque session token.
   */
  async login({ username, password, deviceName, ipAddress }: AuthInput): Promise<AuthResult> {
    if (!username || !password) {
      throw new Error("Username and password are required");
    }

    const trimmedUsername = username.trim().toLowerCase();

    const lockState = getLoginLock(trimmedUsername);
    if (Date.now() < lockState.lockedUntil) {
      // Rejected before touching the database — nothing to leak, no counter change.
      const retryAfterSeconds = Math.max(
        1,
        Math.ceil((lockState.lockedUntil - Date.now()) / 1000),
      );
      throw new LoginLockedError(retryAfterSeconds);
    }

    const user = await authRepository.findByUsername(trimmedUsername);

    // Generic response prevents username enumeration attacks
    if (!user || !user.password) {
      throw new Error("Invalid username or password");
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      // Wrong password → count it and maybe lock. This is the only path that
      // increments the counter; network/db failures never do.
      const state = getLoginLock(trimmedUsername);
      state.failedAttempts += 1;

      if (state.failedAttempts >= MAX_FAILED_LOGIN_ATTEMPTS) {
        state.lockCount += 1;
        const stepIndex = Math.min(
          state.lockCount - 1,
          LOCK_DURATION_STEPS_MS.length - 1,
        );
        const durationMs =
          LOCK_DURATION_STEPS_MS[stepIndex] ?? 60 * 60 * 1000;
        state.lockedUntil = Date.now() + durationMs;
        console.warn(
          `[login] Lockout applied for "${trimmedUsername}" (${state.lockCount}${state.lockCount > 1 ? "th" : "st"} lock, ${Math.round(durationMs / 60000)} min)`,
        );
      }

      loginLocks.set(trimmedUsername, state);

      throw new Error("Invalid username or password");
    }

    // Correct credentials → clear the lockout history for this account.
    loginLocks.delete(trimmedUsername);

    const cleanDevice = deviceName || "Mobile Device";
    const token = await authRepository.createSession(user.id, cleanDevice, ipAddress);

    return {
      token,
      user: {
        id: user.id,
        username: user.username,
      },
    };
  },

  /**
   * Validates a raw opaque token against RAM cache or PostgreSQL
   */
  async validateSessionToken(rawToken: string) {
    if (!rawToken || typeof rawToken !== "string") return null;
    return await authRepository.validateSession(rawToken);
  },

  /**
   * Get public profile of the authenticated user
   */
  async getCurrentUser(userId?: number) {
    if (!userId) {
      throw new Error("Not authenticated");
    }

    const user = await authRepository.findById(userId);
    if (!user) {
      throw new Error("User not found");
    }

    return user;
  },

  /**
   * Optimized password verification (1 query lookup directly by user ID)
   */
  async verifyPassword(userId: number, passwordToCheck: string): Promise<boolean> {
    if (!passwordToCheck) {
      throw new Error("Password is required");
    }

    // Direct lookup by ID saves 1 network roundtrip to Supabase
    const user = await authRepository.findById(userId);
    if (!user) {
      throw new Error("User not found");
    }

    // Fetch credentials directly to verify
    const credentials = await authRepository.findByUsername(user.username);
    if (!credentials || !credentials.password) {
      throw new Error("Credentials missing");
    }

    const isMatch = await bcrypt.compare(passwordToCheck, credentials.password);
    if (!isMatch) {
      throw new Error("Incorrect password");
    }

    return true;
  },

  /**
   * Changes password and revokes all other active devices for security
   */
  async changePassword(
    userId: number,
    currentPassword?: string,
    newPassword?: string,
    currentToken?: string
  ) {
    if (!currentPassword || !newPassword) {
      throw new Error("Current password and new password are required");
    }

    if (newPassword.length < 6 || newPassword.length > 72) {
      throw new Error("New password must be between 6 and 72 characters long");
    }

    await this.verifyPassword(userId, currentPassword);

    const hashedNewPassword = await bcrypt.hash(newPassword, 10);
    const updatedUser = await authRepository.updatePassword(userId, hashedNewPassword);

    if (!updatedUser) {
      throw new Error("Failed to update password");
    }

    // Revoke all other active sessions across devices
    if (currentToken) {
      await authRepository.revokeOtherSessions(userId, currentToken);
    }

    return { success: true };
  },

  // --- SESSION MANAGEMENT ---

  async logout(currentToken: string): Promise<boolean> {
    if (!currentToken) return false;
    return await authRepository.revokeSession(currentToken);
  },

// auth.service.ts
async getActiveSessions(userId: number, currentRawToken: string) {
  const currentSession = await authRepository.validateSession(currentRawToken);
  const currentSessionId = currentSession?.sessionId;

  const sessions = await authRepository.getUserSessions(userId);

  return sessions.map((s) => ({
    id: s.id,
    deviceName: s.device_name,
    ipAddress: s.ip_address,
    lastActiveAt: s.last_active_at,
    isCurrentDevice: s.id === currentSessionId, // Guaranteed strict check
  }));
},

  async revokeSessionById(userId: number, sessionId: number): Promise<{ revoked: boolean; revokedUserId: number | null }> {
    return await authRepository.revokeSessionById(sessionId, userId);
  },

  async terminateOtherSessions(userId: number, currentToken: string): Promise<number> {
    return await authRepository.revokeOtherSessions(userId, currentToken);
  },
};