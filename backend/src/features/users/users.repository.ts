import { db } from "../../db";

export const userRepository = {
  async getUserById(userId: number) {
  try {
    return await db.query(
      `SELECT 
        id, 
        username, 
        avatar, 
        bio,
        status,
        last_seen    AS "lastSeen",
        birth_date   AS "birthDate"
       FROM users WHERE id = $1`,
      [userId]
    );
  } catch (err) {
    console.error("DB ERROR (getUserById):", err);
    throw err;
  }
},

  async updateProfile(userId: number, username: string, bio: string, birthDate: string) {
    try {
      return await db.query(
        `UPDATE users 
         SET username = $1, bio = $2, birth_date = $3::DATE 
         WHERE id = $4 
         RETURNING id, username, avatar, birth_date as "birthDate", bio, last_seen as "lastSeen", status`,
        [username, bio, birthDate, userId]
      );
    } catch (err) {
      console.error("DB ERROR (updateProfile):", err);
      throw err;
    }
  },

  async updateAvatar(userId: number, avatarUrl: string) {
    try {
      return await db.query(
        `UPDATE users SET avatar = $1 WHERE id = $2 
         RETURNING id, username, avatar, bio, birth_date as "birthDate"`,
        [avatarUrl, userId]
      );
    } catch (err) {
      console.error("DB ERROR (updateAvatar):", err);
      throw err;
    }
  },

  async updateLastSeen(userId: number) {
  try {
    return await db.query(
      `UPDATE users SET last_seen = NOW() WHERE id = $1
       RETURNING id, last_seen as "lastSeen"`,
      [userId]
    );
  } catch (err) {
    console.error("DB ERROR (updateLastSeen):", err);
    throw err;
  }
},

};