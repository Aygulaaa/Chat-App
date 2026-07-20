import { db } from '../../db';

export const contactsRepository = {
  async getContacts(userId: number) {
    return await db.query(`
      SELECT 
        u.id,
        u.username,
        u.avatar,
        u.bio,
        u.last_seen AS "lastSeen",
        c.status,
        c.created_at AS "createdAt",
        true AS "isContact",
        false AS "isBlocked"
      FROM contacts c
      JOIN users u ON u.id = c.contact_user_id
      WHERE c.user_id = $1
        AND c.status = 'active'
      ORDER BY u.username ASC
    `, [userId]);
  },

    async getBlockedContacts(userId: number) {
    return await db.query(`
      SELECT 
        u.id,
        u.username,
        u.avatar,
        u.bio,
        u.last_seen AS "lastSeen",
        c.status,
        c.created_at AS "createdAt",
        false AS "isContact",
        true AS "isBlocked"
      FROM contacts c
      JOIN users u ON u.id = c.contact_user_id
      WHERE c.user_id = $1
        AND c.status = 'blocked'
      ORDER BY u.username ASC
    `, [userId]);
  },

  async searchUsers(query: string, currentUserId: number) {
    return await db.query(`
      SELECT 
        u.id,
        u.username,
        u.avatar,
        u.bio,
        EXISTS(
          SELECT 1 FROM contacts c
          WHERE c.user_id = $2
            AND c.contact_user_id = u.id
            AND c.status = 'active'
        ) AS "isContact",
        EXISTS(
          SELECT 1 FROM contacts c
          WHERE c.user_id = $2
            AND c.contact_user_id = u.id
            AND c.status = 'blocked'
        ) AS "isBlocked"
      FROM users u
      WHERE u.username ILIKE $1
        AND u.id != $2
      LIMIT 20
    `, [`%${query}%`, currentUserId]);
  },


  async addContact(userId: number, contactId: number) {
    const updateResult = await db.query(
      `
      UPDATE contacts
      SET status = 'active'
      WHERE user_id = $1 AND contact_user_id = $2
      RETURNING *
      `,
      [userId, contactId]
    );

    if (updateResult.rowCount === 0) {
      return await db.query(
        `
        INSERT INTO contacts (user_id, contact_user_id, status)
        VALUES ($1, $2, 'active')
        RETURNING *
        `,
        [userId, contactId]
      );
    }

    return updateResult;
  },


  async removeContact(userId: number, contactId: number) {
    return await db.query(`
      DELETE FROM contacts
      WHERE user_id = $1 AND contact_user_id = $2
      RETURNING *
    `, [userId, contactId]);
  },


  async blockUser(userId: number, contactId: number) {
    const updateResult = await db.query(
      `
      UPDATE contacts
      SET status = 'blocked'
      WHERE user_id = $1 AND contact_user_id = $2
      RETURNING *
      `,
      [userId, contactId]
    );

    if (updateResult.rowCount === 0) {
      return await db.query(
        `
        INSERT INTO contacts (user_id, contact_user_id, status)
        VALUES ($1, $2, 'blocked')
        RETURNING *
        `,
        [userId, contactId]
      );
    }

    return updateResult;
  },

  async unblockUser(userId: number, contactId: number) {
    return await db.query(
      `
      UPDATE contacts
      SET status = 'active'
      WHERE user_id = $1 AND contact_user_id = $2
      RETURNING *
      `,
      [userId, contactId]
    );
  },
};