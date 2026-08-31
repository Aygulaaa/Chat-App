import { db } from "../../db";

// chat.repository.ts
export const chatRepository = {
  async markUndeliveredMessagesForUser(userId: number, io?: any) {
    try {
      const result = await db.query(
        `
        UPDATE messages m
        SET delivered_at = COALESCE(m.delivered_at, NOW())
        FROM chat_members cm
        WHERE cm.chat_id = m.chat_id
          AND cm.user_id = $1
          AND m.sender_id != $1
          AND m.delivered_at IS NULL
          AND NOT EXISTS (
            SELECT 1 FROM contacts block_c
            WHERE ((block_c.user_id = $1 AND block_c.contact_user_id = m.sender_id)
               OR (block_c.user_id = m.sender_id AND block_c.contact_user_id = $1))
              AND block_c.status = 'blocked'
          )
        RETURNING m.id, m.chat_id, m.sender_id, m.delivered_at
        `,
        [userId]
      );

      if (result.rows.length > 0 && io) {
        const senderMap = new Map<number, { chatId: number; messageIds: number[]; deliveredAt: Date }>();
        for (const row of result.rows) {
          const senderId = Number(row.sender_id);
          const chatId = Number(row.chat_id);
          const msgId = Number(row.id);
          if (!senderMap.has(senderId)) {
            senderMap.set(senderId, { chatId, messageIds: [], deliveredAt: row.delivered_at });
          }
          senderMap.get(senderId)!.messageIds.push(msgId);
        }

        for (const [senderId, payload] of senderMap.entries()) {
          io.to(`user_${senderId}`).emit("messages_delivered", {
            chatId: payload.chatId,
            messageIds: payload.messageIds,
            deliveredAt: payload.deliveredAt,
          });
        }
      }
      return result.rows;
    } catch (err) {
      console.error("markUndeliveredMessagesForUser DB ERROR:", err);
      return [];
    }
  },

  async getChats(userId: number) {
    const result = await db.query(
      `
      WITH user_chats AS (
        SELECT DISTINCT chat_id 
        FROM chat_members 
        WHERE user_id = $1
      ),
      chat_participants AS (
        SELECT 
          cm.chat_id,
          json_agg(
            json_build_object(
              'id', u.id,
              'username', u.username,
              'avatar', u.avatar
            )
          ) AS participants
        FROM (
          SELECT DISTINCT chat_id, user_id
          FROM chat_members
          WHERE chat_id IN (SELECT chat_id FROM user_chats)
        ) cm
        JOIN users u ON u.id = cm.user_id
        GROUP BY cm.chat_id
      )
      SELECT 
        c.id,
        c.name,
        c.type,
        c.avatar,
        c.created_by AS "createdBy",
        cp.participants,
        lm.last_message AS "lastMessage",
        COALESCE(um.unread_count, 0) AS "unreadCount"
      FROM chats c
      JOIN user_chats uc ON c.id = uc.chat_id
      JOIN chat_participants cp ON cp.chat_id = c.id
      LEFT JOIN LATERAL (
        SELECT 
          json_build_object(
            'id', m.id,
            'chatId', m.chat_id,
            'senderId', m.sender_id,
            'text', m.text,
            'fileUrl', m.file_url,
            'fileType', m.file_type,
            'originalName', m.original_name,
            'mimeType', m.mime_type,
            'fileSize', m.file_size,
            'createdAt', m.created_at,
            'deliveredAt', m.delivered_at,
            'readAt', m.read_at
          ) AS last_message,
          m.created_at
        FROM messages m
        WHERE m.chat_id = c.id
          AND NOT EXISTS (
            SELECT 1 FROM contacts block_c
            WHERE ((block_c.user_id = $1 AND block_c.contact_user_id = m.sender_id)
               OR (block_c.user_id = m.sender_id AND block_c.contact_user_id = $1))
              AND block_c.status = 'blocked'
          )
        ORDER BY m.created_at DESC
        LIMIT 1
      ) lm ON TRUE
      LEFT JOIN LATERAL (
        SELECT COUNT(*)::int AS unread_count
        FROM messages m
        WHERE m.chat_id = c.id
          AND m.sender_id != $1
          AND m.read_at IS NULL
          AND NOT EXISTS (
            SELECT 1 FROM contacts block_c
            WHERE ((block_c.user_id = $1 AND block_c.contact_user_id = m.sender_id)
               OR (block_c.user_id = m.sender_id AND block_c.contact_user_id = $1))
              AND block_c.status = 'blocked'
          )
      ) um ON TRUE
      ORDER BY lm.created_at DESC NULLS LAST;
    `,
      [userId]
    );
    return result.rows;
  },

  async getChat(chatId: number, userId: number) {
    const result = await db.query(
      `
      WITH chat_participants AS (
        SELECT 
          cm.chat_id,
          json_agg(
            json_build_object(
              'id', u.id,
              'username', u.username,
              'avatar', u.avatar
            )
          ) AS participants
        FROM (
          SELECT DISTINCT chat_id, user_id
          FROM chat_members
          WHERE chat_id = $1
        ) cm
        JOIN users u ON u.id = cm.user_id
        GROUP BY cm.chat_id
      )
      SELECT 
        c.id,
        c.name,
        c.type,
        c.avatar,
        c.created_by AS "createdBy",
        cp.participants,
        lm.last_message AS "lastMessage",
        COALESCE(um.unread_count, 0) AS "unreadCount"
      FROM chats c
      JOIN chat_participants cp ON cp.chat_id = c.id
      LEFT JOIN LATERAL (
        SELECT json_build_object(
          'id', m.id,
          'chatId', m.chat_id,
          'senderId', m.sender_id,
          'text', m.text,
          'fileUrl', m.file_url,
          'fileType', m.file_type,
          'originalName', m.original_name,
          'mimeType', m.mime_type,
          'fileSize', m.file_size,
          'createdAt', m.created_at,
          'deliveredAt', m.delivered_at,
          'readAt', m.read_at
        ) AS last_message
        FROM messages m
        WHERE m.chat_id = c.id
          AND NOT EXISTS (
            SELECT 1 FROM contacts block_c
            WHERE ((block_c.user_id = $2 AND block_c.contact_user_id = m.sender_id)
               OR (block_c.user_id = m.sender_id AND block_c.contact_user_id = $2))
              AND block_c.status = 'blocked'
          )
        ORDER BY m.created_at DESC
        LIMIT 1
      ) lm ON TRUE
      LEFT JOIN LATERAL (
        SELECT COUNT(*)::int AS unread_count
        FROM messages m
        WHERE m.chat_id = c.id
          AND m.sender_id != $2
          AND m.read_at IS NULL
          AND NOT EXISTS (
            SELECT 1 FROM contacts block_c
            WHERE ((block_c.user_id = $2 AND block_c.contact_user_id = m.sender_id)
               OR (block_c.user_id = m.sender_id AND block_c.contact_user_id = $2))
              AND block_c.status = 'blocked'
          )
      ) um ON TRUE
      WHERE c.id = $1
        AND EXISTS (
          SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2
        );
    `,
      [chatId, userId]
    );
    return result.rows[0] ?? null;
  },

  async getMessages(chatId: number, userId: number, limit = 50, beforeId?: number) {
    const result = await db.query(
      `
      SELECT 
        m.id,
        m.chat_id as "chatId",
        m.sender_id as "senderId",
        m.text,
        m.file_type as "fileType",
        m.file_url as "fileUrl",
        m.original_name as "originalName",
        m.mime_type as "mimeType",
        m.file_size as "fileSize",
        m.created_at as "createdAt",  
        m.delivered_at AS "deliveredAt",
        m.read_at AS "readAt"
      FROM messages m
      WHERE m.chat_id = $1 
        AND ($3::int IS NULL OR m.id < $3)
        AND NOT EXISTS (
          SELECT 1 FROM contacts c 
          WHERE ((c.user_id = $2 AND c.contact_user_id = m.sender_id)
             OR (c.user_id = m.sender_id AND c.contact_user_id = $2))
            AND c.status = 'blocked'
        )
      ORDER BY m.id DESC
      LIMIT $4
    `,
      [chatId, userId, beforeId ?? null, limit]
    );
    return result.rows;
  },

  async getMessageById(messageId: number, userId: number) {
    const result = await db.query(
      `
      SELECT 
        m.id,
        m.chat_id as "chatId",
        m.sender_id as "senderId",
        m.text,
        m.file_type as "fileType",
        m.file_url as "fileUrl",
        m.original_name as "originalName",
        m.mime_type as "mimeType",
        m.file_size as "fileSize",
        m.created_at as "createdAt",  
        m.delivered_at AS "deliveredAt",
        m.read_at AS "readAt"
      FROM messages m
      WHERE m.id = $1
        AND EXISTS (
          SELECT 1 FROM chat_members WHERE chat_id = m.chat_id AND user_id = $2
        )
      LIMIT 1
      `,
      [messageId, userId]
    );
    return result.rows[0] ?? null;
  },

  async sendMessage(chatId: number, senderId: number, text: string) {
    const result = await db.query(
      `
      INSERT INTO messages (chat_id, sender_id, text)
      SELECT $1, $2, $3
      WHERE EXISTS (
        SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2
      )
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
    `,
      [chatId, senderId, text]
    );
    return result.rows[0] ?? null;
  },

  async sendFileMessage(
    chatId: number,
    senderId: number,
    fileUrl: string,
    fileType: string,
    originalName: string,
    mimeType: string,
    fileSize: number
  ) {
    const result = await db.query(
      `
      INSERT INTO messages (
        chat_id, sender_id,
        file_url, file_type, original_name, mime_type, file_size
      )
      SELECT $1, $2, $3, $4, $5, $6, $7
      WHERE EXISTS (
        SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2
      )
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
    `,
      [chatId, senderId, fileUrl, fileType, originalName, mimeType, fileSize]
    );
    return result.rows[0] ?? null;
  },

  async markMessagesDelivered(chatId: number, recipientId: number) {
    const result = await db.query(
      `
      UPDATE messages
      SET delivered_at = NOW()
      WHERE chat_id = $1
        AND sender_id != $2
        AND delivered_at IS NULL
        AND EXISTS (
          SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2
        )
        AND NOT EXISTS (
            SELECT 1 FROM contacts block_c
            WHERE ((block_c.user_id = $2 AND block_c.contact_user_id = messages.sender_id)
               OR (block_c.user_id = messages.sender_id AND block_c.contact_user_id = $2))
              AND block_c.status = 'blocked'
        )
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
    return result.rows;
  },

  async markMessagesRead(chatId: number, readerId: number) {
    const result = await db.query(
      `
      UPDATE messages
      SET 
        delivered_at = COALESCE(delivered_at, NOW()),
        read_at = NOW()
      WHERE chat_id = $1
        AND sender_id != $2
        AND read_at IS NULL
        AND EXISTS (
          SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2
        )
        AND NOT EXISTS (
            SELECT 1 FROM contacts block_c
            WHERE ((block_c.user_id = $2 AND block_c.contact_user_id = messages.sender_id)
               OR (block_c.user_id = messages.sender_id AND block_c.contact_user_id = $2))
              AND block_c.status = 'blocked'
        )
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
    return result.rows;
  },

  async createChat(userId: number, contactId: number) {
    if (userId === contactId) {
      throw new Error("Cannot create chat with yourself");
    }

    const client = await db.connect();
    try {
      await client.query("BEGIN");

      const existing = await client.query(
        `
        SELECT c.id
        FROM chats c
        JOIN chat_members m1 ON m1.chat_id = c.id AND m1.user_id = $1
        JOIN chat_members m2 ON m2.chat_id = c.id AND m2.user_id = $2
        WHERE c.type = 'private'
        LIMIT 1
      `,
        [userId, contactId]
      );

      if (existing.rows.length > 0) {
        await client.query("COMMIT");
        return { id: existing.rows[0].id };
      }

      const chat = await client.query(
        `
        INSERT INTO chats (type) 
        VALUES ('private') 
        RETURNING id
      `
      );

      const chatId = chat.rows[0].id;

      await client.query(
        `
        INSERT INTO chat_members (chat_id, user_id)
        VALUES ($1, $2), ($1, $3)
      `,
        [chatId, userId, contactId]
      );

      await client.query("COMMIT");
      return { id: chatId };
    } catch (err) {
      await client.query("ROLLBACK");
      console.error("DB ERROR createChat:", err);
      throw err;
    } finally {
      client.release();
    }
  },

  async createGroupChat(
    creatorId: number,
    name: string,
    memberIds: number[],
    avatar?: string
  ) {
    const client = await db.connect();
    try {
      await client.query("BEGIN");

      const chat = await client.query(
        `
        INSERT INTO chats (name, type, created_by, avatar)
        VALUES ($1, 'group', $2, $3)
        RETURNING id
      `,
        [name, creatorId, avatar ?? null]
      );

      const chatId = chat.rows[0].id;
      const allMembers = [...new Set([creatorId, ...memberIds])];

      const valuePlaceholders = allMembers
        .map((_, index) => `($1, $${index + 2})`)
        .join(", ");

      await client.query(
        `INSERT INTO chat_members (chat_id, user_id) VALUES ${valuePlaceholders}`,
        [chatId, ...allMembers]
      );

      await client.query("COMMIT");
      return { id: chatId };
    } catch (err) {
      await client.query("ROLLBACK");
      console.error("DB ERROR createGroupChat:", err);
      throw err;
    } finally {
      client.release();
    }
  },

  async addMemberToGroup(chatId: number, userId: number) {
    const result = await db.query(
      `
      INSERT INTO chat_members (chat_id, user_id)
      VALUES ($1, $2)
      ON CONFLICT DO NOTHING
      RETURNING *
    `,
      [chatId, userId]
    );
    return result.rows[0] ?? null;
  },

  async removeMemberFromGroup(chatId: number, userId: number) {
    const result = await db.query(
      `
      DELETE FROM chat_members
      WHERE chat_id = $1 AND user_id = $2
      RETURNING *
    `,
      [chatId, userId]
    );
    return result.rows[0] ?? null;
  },

  async updateGroupInfo(chatId: number, name?: string, avatar?: string) {
    const fields: string[] = [];
    const values: any[] = [chatId];
    let i = 2;

    if (name !== undefined) {
      fields.push(`name = $${i++}`);
      values.push(name);
    }
    if (avatar !== undefined) {
      fields.push(`avatar = $${i++}`);
      values.push(avatar);
    }
    if (fields.length === 0) throw new Error("Nothing to update");

    const result = await db.query(
      `
      UPDATE chats SET ${fields.join(", ")}
      WHERE id = $1
      RETURNING id, name, avatar, type
    `,
      values
    );
    return result.rows[0] ?? null;
  },

  async deleteMessage(messageId: number, senderId: number) {
    const result = await db.query(
      `DELETE FROM messages
       WHERE id = $1 AND sender_id = $2
       RETURNING id, chat_id AS "chatId"`,
      [messageId, senderId]
    );
    return result.rows[0] ?? null;
  },

  async deleteChat(chatId: number) {
    const result = await db.query(
      `
      DELETE FROM chats
      WHERE id = $1
      RETURNING id
    `,
      [chatId]
    );
    return result.rows[0] ?? null;
  },

  async deleteGroup(chatId: number, requesterId: number) {
    const client = await db.connect();
    try {
      await client.query("BEGIN");

      const chatResult = await client.query(
        `SELECT id, created_by, type FROM chats WHERE id = $1 FOR UPDATE`,
        [chatId]
      );

      if (chatResult.rowCount === 0) {
        throw new Error("Group not found");
      }

      const chat = chatResult.rows[0];
      if (chat.type !== "group") {
        throw new Error("This is not a group chat");
      }
      if (chat.created_by !== requesterId) {
        throw new Error("Only the group creator can delete the group");
      }

      const membersResult = await client.query(
        `SELECT user_id FROM chat_members WHERE chat_id = $1`,
        [chatId]
      );
      const memberIds: number[] = membersResult.rows.map((r: any) => r.user_id);

      await client.query(`DELETE FROM messages WHERE chat_id = $1`, [chatId]);
      await client.query(`DELETE FROM chat_members WHERE chat_id = $1`, [chatId]);
      await client.query(`DELETE FROM chats WHERE id = $1`, [chatId]);

      await client.query("COMMIT");
      return { chatId, memberIds };
    } catch (err) {
      await client.query("ROLLBACK");
      console.error("DB ERROR deleteGroup:", err);
      throw err;
    } finally {
      client.release();
    }
  },
};