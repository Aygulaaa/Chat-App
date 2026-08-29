import bcrypt from "bcryptjs";
import { authRepository, UserSessionRow } from "./auth.repository";

export interface AuthInput {
  username?: string;
  password?: string;
  deviceName?: string;
  ipAddress?: string;
}

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
    const user = await authRepository.findByUsername(trimmedUsername);

    // Generic response prevents username enumeration attacks
    if (!user || !user.password) {
      throw new Error("Invalid username or password");
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      throw new Error("Invalid username or password");
    }

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

  async getActiveSessions(userId: number, currentToken: string): Promise<SessionFormatted[]> {
    const sessions = await authRepository.getUserSessions(userId);
    const currentHash = authRepository.hashToken(currentToken);

    return sessions.map((s) => ({
      id: s.id,
      deviceName: s.device_name,
      ipAddress: s.ip_address || undefined,
      lastActiveAt: s.last_active_at,
      createdAt: s.created_at,
      isCurrentDevice: s.token_hash === currentHash,
    }));
  },

  async revokeSessionById(userId: number, sessionId: number): Promise<boolean> {
    return await authRepository.revokeSessionById(sessionId, userId);
  },

  async terminateOtherSessions(userId: number, currentToken: string): Promise<number> {
    return await authRepository.revokeOtherSessions(userId, currentToken);
  },
};