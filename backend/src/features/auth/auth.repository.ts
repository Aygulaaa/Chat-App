import db from "../../db";
import crypto from "crypto";

export interface UserRow {
  id: number;
  username: string;
  password?: string;
  created_at?: Date;
}

export interface UserSessionRow {
  id: number;
  user_id: number;
  token_hash: string;
  device_name: string;
  ip_address?: string;
  last_active_at: Date;
  created_at: Date;
}

export interface ValidatedSession {
  userId: number;
  sessionId: number;
}

// -----------------------------------------------------------------------------
// In-Memory Cache (Saves Supabase free-tier database calls)
// -----------------------------------------------------------------------------
interface CachedSession {
  session: ValidatedSession;
  cachedAt: number;
  lastActiveInDb: number;
}

const sessionCache = new Map<string, CachedSession>();
const CACHE_TTL_MS = 60 * 1000;              // 1 minute local RAM cache
const DB_UPDATE_THROTTLE_MS = 15 * 60 * 1000; // Update Supabase at most every 15 mins

export const authRepository = {
  hashToken(token: string): string {
    if (!token || typeof token !== "string" || token.trim() === "") {
      throw new Error("Invalid token format provided for hashing");
    }
    return crypto.createHash("sha256").update(token).digest("hex");
  },

  /**
   * Creates user and user_settings in 1 single network roundtrip to Supabase
   */
  async createUser(username: string, hashedPassword: string): Promise<UserRow> {
    const result = await db.query<UserRow>(
      `WITH new_user AS (
         INSERT INTO users (username, password)
         VALUES ($1, $2)
         RETURNING id, username
       ),
       new_settings AS (
         INSERT INTO user_settings (user_id)
         SELECT id FROM new_user
       )
       SELECT id, username FROM new_user`,
      [username, hashedPassword]
    );

    const user = result.rows[0];
    if (!user) {
      throw new Error("Failed to create user");
    }

    return user;
  },

  async findByUsername(username: string): Promise<UserRow | undefined> {
    const result = await db.query<UserRow>(
      `SELECT id, username, password FROM users WHERE username = $1`,
      [username]
    );
    return result.rows[0];
  },

  async findById(id: number): Promise<UserRow | undefined> {
    const result = await db.query<UserRow>(
      `SELECT id, username FROM users WHERE id = $1`,
      [id]
    );
    return result.rows[0];
  },

  async updatePassword(id: number, hashedPassword: string): Promise<UserRow | undefined> {
    const result = await db.query<UserRow>(
      `UPDATE users SET password = $1 WHERE id = $2 RETURNING id, username`,
      [hashedPassword, id]
    );
    return result.rows[0];
  },

  // --- OPAQUE SESSION MANAGEMENT ---

  async createSession(
    userId: number,
    deviceName = "Mobile Device",
    ipAddress?: string
  ): Promise<string> {
    const rawToken = crypto.randomBytes(32).toString("hex");
    const tokenHash = this.hashToken(rawToken);

    await db.query(
      `INSERT INTO user_sessions (user_id, token_hash, device_name, ip_address)
       VALUES ($1, $2, $3, $4)`,
      [userId, tokenHash, deviceName, ipAddress || null]
    );

    return rawToken;
  },

  /**
   * Highly optimized validation for Supabase + Render
   */
  async validateSession(rawToken: string): Promise<ValidatedSession | null> {
    if (!rawToken || typeof rawToken !== "string" || rawToken.trim() === "") {
      return null;
    }

    const tokenHash = this.hashToken(rawToken);
    const now = Date.now();

    // 1. Check Render process memory cache first (0 DB queries)
    const cached = sessionCache.get(tokenHash);
    if (cached && now - cached.cachedAt < CACHE_TTL_MS) {
      return cached.session;
    }

    // 2. Fetch from Supabase only on cache miss
    const result = await db.query<{
      id: number;
      user_id: number;
      last_active_at: Date;
    }>(
      `SELECT id, user_id, last_active_at
       FROM user_sessions
       WHERE token_hash = $1`,
      [tokenHash]
    );

    if (result.rowCount === 0 || !result.rows[0]) {
      sessionCache.delete(tokenHash);
      return null;
    }

    const row = result.rows[0];
    const sessionData: ValidatedSession = {
      userId: row.user_id,
      sessionId: row.id,
    };

    const lastActiveDbTime = new Date(row.last_active_at).getTime();

    // 3. Update RAM cache
    sessionCache.set(tokenHash, {
      session: sessionData,
      cachedAt: now,
      lastActiveInDb: lastActiveDbTime,
    });

    // 4. Fire-and-forget UPDATE to Supabase at most every 15 minutes
    if (now - lastActiveDbTime > DB_UPDATE_THROTTLE_MS) {
      db.query(
        `UPDATE user_sessions SET last_active_at = NOW() WHERE id = $1`,
        [row.id]
      ).catch(() => {}); // Prevent unhandled promise rejections on network blips
    }

    return sessionData;
  },

  async getUserSessions(userId: number): Promise<UserSessionRow[]> {
    const result = await db.query<UserSessionRow>(
      `SELECT id, user_id, token_hash, device_name, ip_address, last_active_at, created_at
       FROM user_sessions
       WHERE user_id = $1
       ORDER BY last_active_at DESC`,
      [userId]
    );
    return result.rows;
  },

  async revokeSession(rawToken: string): Promise<boolean> {
    if (!rawToken || typeof rawToken !== "string" || rawToken.trim() === "") {
      return false;
    }

    const tokenHash = this.hashToken(rawToken);
    sessionCache.delete(tokenHash); // Clear local cache immediately

    const result = await db.query(
      `DELETE FROM user_sessions WHERE token_hash = $1`,
      [tokenHash]
    );
    return (result.rowCount ?? 0) > 0;
  },

  async revokeSessionById(sessionId: number, userId: number): Promise<boolean> {
    // Clear matches from local RAM cache
    for (const [hash, entry] of sessionCache.entries()) {
      if (entry.session.sessionId === sessionId) {
        sessionCache.delete(hash);
      }
    }

    const result = await db.query(
      `DELETE FROM user_sessions WHERE id = $1 AND user_id = $2`,
      [sessionId, userId]
    );
    return (result.rowCount ?? 0) > 0;
  },

  async revokeOtherSessions(userId: number, currentRawToken: string): Promise<number> {
    if (!currentRawToken || typeof currentRawToken !== "string" || currentRawToken.trim() === "") {
      return 0;
    }

    const currentHash = this.hashToken(currentRawToken);

    // Evict all user cached items except current token
    for (const [hash, entry] of sessionCache.entries()) {
      if (entry.session.userId === userId && hash !== currentHash) {
        sessionCache.delete(hash);
      }
    }

    const result = await db.query(
      `DELETE FROM user_sessions WHERE user_id = $1 AND token_hash != $2`,
      [userId, currentHash]
    );
    return result.rowCount ?? 0;
  },
};