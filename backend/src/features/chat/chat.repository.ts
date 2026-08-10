import { db } from "../../db";

export const chatRepository = {

  async getChats(userId: number) {
    return await db.query(`
      SELECT 
        c.id,
        c.name,
        c.type,
        c.avatar,
        c.created_by AS "createdBy",

        json_agg(
          json_build_object(
            'id', u.id,
            'username', u.username,
            'avatar', u.avatar
          )
        ) AS participants,

        (
          SELECT json_build_object(
            'id', m.id,
            'chatId', m.chat_id,
            'senderId', m.sender_id,
            'text', m.text,
            'createdAt', to_json(m.created_at),
            'deliveredAt', to_json(m.delivered_at),
            'readAt', to_json(m.read_at)
          )
          FROM messages m
          WHERE m.chat_id = c.id
          ORDER BY m.created_at DESC
          LIMIT 1
        ) AS "lastMessage",

        (
          SELECT COUNT(*)::int
          FROM messages m
          WHERE m.chat_id = c.id
            AND m.sender_id != $1
            AND m.read_at IS NULL
        ) AS "unreadCount"

      FROM chats c

      JOIN chat_members cm
        ON cm.chat_id = c.id

      JOIN users u
        ON u.id = cm.user_id

      WHERE c.id IN (
        SELECT chat_id
        FROM chat_members
        WHERE user_id = $1
      )

      GROUP BY 
        c.id,
        c.name,
        c.type,
        c.avatar,
        c.created_by

      ORDER BY (
        SELECT m.created_at
        FROM messages m
        WHERE m.chat_id = c.id
        ORDER BY m.created_at DESC
        LIMIT 1
      ) DESC NULLS LAST
    `, [userId]);
  },

  async getChat(chatId: number, userId: number) {
    return await db.query(`
      SELECT 
        c.id,
        c.name,
        c.type,
        c.avatar,
        c.created_by AS "createdBy",

        json_agg(
          json_build_object(
            'id', u.id,
            'username', u.username,
            'avatar', u.avatar
          )
        ) AS participants,

        (
          SELECT json_build_object(
            'id', m.id,
            'chatId', m.chat_id,
            'senderId', m.sender_id,
            'text', m.text,
            'createdAt', to_json(m.created_at),
            'deliveredAt', to_json(m.delivered_at),
            'readAt', to_json(m.read_at)
          )
          FROM messages m
          WHERE m.chat_id = c.id
          ORDER BY m.created_at DESC
          LIMIT 1
        ) AS "lastMessage",

        (
          SELECT COUNT(*)::int
          FROM messages m
          WHERE m.chat_id = c.id
            AND m.sender_id != $2
            AND m.read_at IS NULL
        ) AS "unreadCount"

      FROM chats c

      JOIN chat_members cm
        ON cm.chat_id = c.id

      JOIN users u
        ON u.id = cm.user_id

      WHERE c.id = $1

      GROUP BY
        c.id,
        c.name,
        c.type,
        c.avatar,
        c.created_by
    `, [chatId, userId]);
  },

  async getMessages(chatId: number) {
    try {
      return await db.query(`
      SELECT 
        m.id,
        m.chat_id as "chatId",
        m.sender_id as "senderId",
        m.text,
        m.file_type as "fileType",
        m.file_url as "fileUrl",
        m.created_at as "createdAt",  
        m.delivered_at AS "deliveredAt",
        m.read_at AS "readAt"
      FROM messages m
      WHERE m.chat_id = $1
      ORDER BY m.created_at DESC
    `, [chatId]);
    } catch (err) {
      console.error("DB ERROR:", err);
      throw err;
    }
  },

  async sendMessage(chatId: number, senderId: number, text: string) {
    try {
      return await db.query(`
      INSERT INTO messages (chat_id, sender_id, text)
      VALUES ($1, $2, $3)
      RETURNING 
        id,
        chat_id as "chatId",
        sender_id as "senderId",
        text,
        file_url as "fileUrl",
        file_type as "fileType",
        original_name as "originalName",
        mime_type as "mimeType",
        file_size as "fileSize",
        created_at as "createdAt", 
        delivered_at AS "deliveredAt",
        read_at AS "readAt"
    `, [chatId, senderId, text]);
    } catch (err) {
      console.error("DB ERROR:", err);
      throw err;
    }
  },

  async markMessagesDelivered(chatId: number, recipientId: number) {
    try {
      return await db.query(
        `
        UPDATE messages
        SET delivered_at = NOW()
        WHERE chat_id = $1
          AND sender_id != $2
          AND delivered_at IS NULL
        RETURNING
          id,
          chat_id       AS "chatId",
          sender_id     AS "senderId",
          text,
          created_at    AS "createdAt",
          delivered_at  AS "deliveredAt",
          read_at       AS "readAt"
        `,
        [chatId, recipientId]
      );
    } catch (err) {
      console.error("DB ERROR markMessagesDelivered:", err);
      throw err;
    }
  },

  async markMessagesRead(chatId: number, readerId: number) {
    try {
      return await db.query(
        `
        UPDATE messages
        SET 
          delivered_at = COALESCE(delivered_at, NOW()),
          read_at = NOW()
        WHERE chat_id = $1
          AND sender_id != $2
          AND read_at IS NULL
        RETURNING
          id,
          chat_id       AS "chatId",
          sender_id     AS "senderId",
          text,
          created_at    AS "createdAt",
          delivered_at  AS "deliveredAt",
          read_at       AS "readAt"
        `,
        [chatId, readerId]
      );
    } catch (err) {
      console.error("DB ERROR markMessagesRead:", err);
      throw err;
    }
  },

  async sendFileMessage(
    chatId: number,
    senderId: number,
    fileUrl: string,
    fileType: string,
    originalName: string,
    mimeType: string,
    fileSize: number) {
    try {
      return await db.query(`
      INSERT INTO messages (
        chat_id, sender_id,
        file_url, file_type, original_name, mime_type, file_size
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING
        id,
        chat_id       AS "chatId",
        sender_id     AS "senderId",
        text,
        file_url      AS "fileUrl",
        file_type     AS "fileType",
        original_name AS "originalName",
        mime_type     AS "mimeType",
        file_size     AS "fileSize",
        created_at    AS "createdAt",
        delivered_at  AS "deliveredAt",
        read_at       AS "readAt"
    `, [chatId, senderId, fileUrl, fileType, originalName, mimeType, fileSize]);
    } catch (err) {
      console.error("DB ERROR sendFileMessage:", err);
      throw err;
    }
  },

  async createChat(userId: number, contactId: number) {
    try {
      if (userId === contactId) {
        throw new Error('Cannot create chat with yourself');
      }

      const existing = await db.query(`
      SELECT c.id
      FROM chats c
      JOIN chat_members m1 ON m1.chat_id = c.id AND m1.user_id = $1
      JOIN chat_members m2 ON m2.chat_id = c.id AND m2.user_id = $2
      LIMIT 1
    `, [userId, contactId]);

      if (existing.rows.length > 0) {
        return { id: existing.rows[0].id };
      }

      const chat = await db.query(`
      INSERT INTO chats (type) 
      VALUES ($1) 
      RETURNING id 
      `, ['private']);

      const chatId = chat.rows[0].id;

      await db.query(`
      INSERT INTO chat_members (chat_id, user_id)
      VALUES ($1, $2), ($1, $3)
    `, [chatId, userId, contactId]);

      return { id: chatId };
    } catch (err) {
      console.error('DB ERROR createChat:', err);
      throw err;
    }
  },


  async createGroupChat(
    creatorId: number,
    name: string,
    memberIds: number[],
    avatar?: string
  ) {
    try {
      const chat = await db.query(`
    INSERT INTO chats (name, type, created_by, avatar)
    VALUES ($1, 'group', $2, $3)
    RETURNING id
  `, [name, creatorId, avatar ?? null]);

      const chatId = chat.rows[0].id;

      const allMembers = [...new Set([creatorId, ...memberIds])];

      for (const memberId of allMembers) {
        await db.query(`
      INSERT INTO chat_members (chat_id, user_id) VALUES ($1, $2)
    `, [chatId, memberId]);
      }

      return { id: chatId };
    } catch (err) {
      console.error('DB ERROR createGroupChat:', err);
      throw err;
    }
  },

  async addMemberToGroup(chatId: number, userId: number) {
    return await db.query(`
    INSERT INTO chat_members (chat_id, user_id)
    VALUES ($1, $2)
    ON CONFLICT DO NOTHING
    RETURNING *
  `, [chatId, userId]);
  },

  async removeMemberFromGroup(chatId: number, userId: number) {
    return await db.query(`
    DELETE FROM chat_members
    WHERE chat_id = $1 AND user_id = $2
    RETURNING *
  `, [chatId, userId]);
  },

  async updateGroupInfo(chatId: number, name?: string, avatar?: string) {
    const fields: string[] = [];
    const values: any[] = [chatId];
    let i = 2;

    if (name !== undefined) { fields.push(`name = $${i++}`); values.push(name); }
    if (avatar !== undefined) { fields.push(`avatar = $${i++}`); values.push(avatar); }
    if (fields.length === 0) throw new Error('Nothing to update');

    return await db.query(`
    UPDATE chats SET ${fields.join(', ')}
    WHERE id = $1
    RETURNING id, name, avatar, type
  `, values);
  },
};
