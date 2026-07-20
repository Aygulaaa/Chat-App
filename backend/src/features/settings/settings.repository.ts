import { db } from '../../db';

export const settingsRepository = {
  async getSettings(userId: number) {
    const result = await db.query(`
      SELECT 
        user_id AS "userId",
        notifications_enabled AS "notificationsEnabled",
        theme,
        hide_last_seen AS "hideLastSeen",
        hide_read_receipts AS "hideReadReceipts",
        updated_at AS "updatedAt"
      FROM user_settings
      WHERE user_id = $1
    `, [userId]);

    if (result.rows.length === 0) {
      return await settingsRepository.createDefaults(userId);
    }

    return result.rows[0];
  },

  async createDefaults(userId: number) {
    const result = await db.query(`
      INSERT INTO user_settings (user_id)
      VALUES ($1)
      ON CONFLICT (user_id) DO NOTHING
      RETURNING
        user_id AS "userId",
        notifications_enabled AS "notificationsEnabled",
        theme,
        hide_last_seen AS "hideLastSeen",
        hide_read_receipts AS "hideReadReceipts",
        updated_at AS "updatedAt"
    `, [userId]);

    return result.rows[0] ?? {
      userId,
      notificationsEnabled: true,
      theme: 'dark',
      hideLastSeen: false,
      hideReadReceipts: false,
    };
  },

  async updateSettings(userId: number, updates: Partial<{
    notificationsEnabled: boolean;
    theme: string;
    hideLastSeen: boolean;
    hideReadReceipts: boolean;
  }>) {
    const fields: string[] = [];
    const values: any[] = [];
    let i = 2;

    if (updates.notificationsEnabled !== undefined) {
      fields.push(`notifications_enabled = $${i++}`);
      values.push(updates.notificationsEnabled);
    }
    if (updates.theme !== undefined) {
      fields.push(`theme = $${i++}`);
      values.push(updates.theme);
    }
    if (updates.hideLastSeen !== undefined) {
      fields.push(`hide_last_seen = $${i++}`);
      values.push(updates.hideLastSeen);
    }
    if (updates.hideReadReceipts !== undefined) {
      fields.push(`hide_read_receipts = $${i++}`);
      values.push(updates.hideReadReceipts);
    }

    if (fields.length === 0) throw new Error('No fields to update');

    fields.push(`updated_at = NOW()`);

    const result = await db.query(`
      UPDATE user_settings
      SET ${fields.join(', ')}
      WHERE user_id = $1
      RETURNING
        user_id AS "userId",
        notifications_enabled AS "notificationsEnabled",
        theme,
        hide_last_seen AS "hideLastSeen",
        hide_read_receipts AS "hideReadReceipts",
        updated_at AS "updatedAt"
    `, [userId, ...values]);

    return result.rows[0];
  },
};