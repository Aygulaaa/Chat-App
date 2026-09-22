import { db } from "../../db";
import type { PoolClient } from "pg";

/** Typed error so controllers can map failures to the right HTTP status. */
export class ChatError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

/**
 * Column list for a message row aliased `m`, including the quoted message
 * (`replyTo`) when the row is a reply. Must be used together with
 * `replyJoins()`. `viewerParam` is the SQL placeholder of the requesting user.
 */
const messageColumns = (viewerParam: string) => `
        m.id,
        m.chat_id       AS "chatId",
        m.sender_id     AS "senderId",
        m.text,
        m.file_type     AS "fileType",
        m.file_url      AS "fileUrl",
        m.original_name AS "originalName",
        m.mime_type     AS "mimeType",
        m.file_size     AS "fileSize",
        m.created_at    AS "createdAt",
        m.delivered_at  AS "deliveredAt",
        -- "read by everyone". Hidden from a sender who turned read receipts
        -- off: the setting is reciprocal, and must hold for fetched history
        -- too, not just for live socket events.
        CASE WHEN m.sender_id = ${viewerParam} AND EXISTS (
               SELECT 1 FROM user_settings vs
                WHERE vs.user_id = ${viewerParam} AND vs.hide_read_receipts = true)
             THEN NULL ELSE m.read_at END AS "readAt",
        m.reply_to_id   AS "replyToId",
        CASE WHEN r.id IS NULL THEN NULL ELSE json_build_object(
          'id', r.id,
          'senderId', r.sender_id,
          'senderName', ru.username,
          'text', LEFT(r.text, 200),
          'fileType', r.file_type,
          'originalName', r.original_name
        ) END AS "replyTo",
        -- Reactions, oldest first. People the viewer has a block with are
        -- left out, the same way their messages are.
        COALESCE((
          SELECT json_agg(json_build_object('userId', mr.user_id, 'emoji', mr.emoji)
                          ORDER BY mr.created_at)
            FROM message_reactions mr
           WHERE mr.message_id = m.id
             AND NOT EXISTS (
               SELECT 1 FROM contacts rc
                WHERE ((rc.user_id = ${viewerParam} AND rc.contact_user_id = mr.user_id)
                    OR (rc.user_id = mr.user_id AND rc.contact_user_id = ${viewerParam}))
                  AND rc.status = 'blocked'
             )
        ), '[]'::json) AS "reactions"`;

/**
 * true when message `alias` was sent while `viewerParam` and its sender had a
 * block between them. That is recorded on the message itself (`hidden_from`),
 * so it stays hidden from that person after an unblock — see migration 004.
 */
export const hiddenFrom = (alias: string, viewerParam: string) =>
  `${viewerParam}::bigint = ANY(${alias}.hidden_from)`;

/** The members a new message from `senderParam` must never reach. */
const blockedMembersOf = (chatParam: string, senderParam: string) => `
        ARRAY(
          SELECT cm.user_id::bigint FROM chat_members cm
           WHERE cm.chat_id = ${chatParam}
             AND cm.user_id <> ${senderParam}
             AND EXISTS (
               SELECT 1 FROM contacts hb
                WHERE ((hb.user_id = cm.user_id AND hb.contact_user_id = ${senderParam})
                    OR (hb.user_id = ${senderParam} AND hb.contact_user_id = cm.user_id))
                  AND hb.status = 'blocked'
             )
        )`;

/**
 * Joins the quoted message. The quote is withheld when the viewer and the
 * quoted message's author have a block between them — otherwise a reply in a
 * group would leak text the viewer is not supposed to see.
 */
const replyJoins = (viewerParam: string) => `
      LEFT JOIN messages r
        ON r.id = m.reply_to_id
       AND NOT ${hiddenFrom('r', viewerParam)}
       AND NOT EXISTS (
         SELECT 1 FROM contacts rb
         WHERE ((rb.user_id = ${viewerParam} AND rb.contact_user_id = r.sender_id)
            OR (rb.user_id = r.sender_id AND rb.contact_user_id = ${viewerParam}))
           AND rb.status = 'blocked'
       )
      LEFT JOIN users ru ON ru.id = r.sender_id`;

/** Removes a chat and everything hanging off it. Caller owns the transaction. */
async function deleteChatCascade(client: PoolClient, chatId: number): Promise<number[]> {
  const membersResult = await client.query(
    `SELECT user_id FROM chat_members WHERE chat_id = $1`,
    [chatId]
  );
  const memberIds: number[] = membersResult.rows.map((r: any) => Number(r.user_id));

  await client.query(`DELETE FROM messages WHERE chat_id = $1`, [chatId]);
  await client.query(`DELETE FROM chat_members WHERE chat_id = $1`, [chatId]);
  await client.query(`DELETE FROM chats WHERE id = $1`, [chatId]);
  return memberIds;
}

// chat.repository.ts
export const chatRepository = {
  async isMember(chatId: number, userId: number): Promise<boolean> {
    const result = await db.query(
      `SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2`,
      [chatId, userId]
    );
    return (result.rowCount ?? 0) > 0;
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
            'readAt', CASE WHEN m.sender_id = $1 AND EXISTS (
                        SELECT 1 FROM user_settings vs
                         WHERE vs.user_id = $1 AND vs.hide_read_receipts = true)
                      THEN NULL ELSE m.read_at END
          ) AS last_message,
          m.created_at
        FROM messages m
        WHERE m.chat_id = c.id
          AND NOT ${hiddenFrom('m', '$1')}
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
          -- unread FOR THIS USER (not "unread by anyone", which broke groups)
          AND m.id > COALESCE((
            SELECT me.last_read_message_id FROM chat_members me
             WHERE me.chat_id = c.id AND me.user_id = $1), 0)
          AND NOT ${hiddenFrom('m', '$1')}
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
          'readAt', CASE WHEN m.sender_id = $2 AND EXISTS (
                      SELECT 1 FROM user_settings vs
                       WHERE vs.user_id = $2 AND vs.hide_read_receipts = true)
                    THEN NULL ELSE m.read_at END
        ) AS last_message
        FROM messages m
        WHERE m.chat_id = c.id
          AND NOT ${hiddenFrom('m', '$2')}
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
          -- unread FOR THIS USER (not "unread by anyone", which broke groups)
          AND m.id > COALESCE((
            SELECT me.last_read_message_id FROM chat_members me
             WHERE me.chat_id = c.id AND me.user_id = $2), 0)
          AND NOT ${hiddenFrom('m', '$2')}
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
    const safeLimit = Math.min(Math.max(Math.trunc(limit) || 50, 1), 100);
    const result = await db.query(
      `
      SELECT ${messageColumns('$2')}
      FROM messages m
      ${replyJoins('$2')}
      WHERE m.chat_id = $1 
        -- Only members may read a chat's history
        AND EXISTS (
          SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2
        )
        AND ($3::bigint IS NULL OR m.id < $3::bigint)
        AND NOT ${hiddenFrom('m', '$2')}
        AND NOT EXISTS (
          SELECT 1 FROM contacts c 
          WHERE ((c.user_id = $2 AND c.contact_user_id = m.sender_id)
             OR (c.user_id = m.sender_id AND c.contact_user_id = $2))
            AND c.status = 'blocked'
        )
      ORDER BY m.id DESC
      LIMIT $4
    `,
      [chatId, userId, beforeId ?? null, safeLimit]
    );
    return result.rows;
  },

  async getMessageById(messageId: number, userId: number) {
    const result = await db.query(
      `
      SELECT ${messageColumns('$2')}
      FROM messages m
      ${replyJoins('$2')}
      WHERE m.id = $1
        AND NOT ${hiddenFrom('m', '$2')}
        AND EXISTS (
          SELECT 1 FROM chat_members WHERE chat_id = m.chat_id AND user_id = $2
        )
      LIMIT 1
      `,
      [messageId, userId]
    );
    return result.rows[0] ?? null;
  },

  /**
   * `replyToId` is only honoured when it points at a message in the SAME chat;
   * anything else is stored as NULL so a client can't quote foreign chats.
   */
  async sendMessage(chatId: number, senderId: number, text: string, replyToId?: number | null) {
    const result = await db.query(
      `
      WITH m AS (
        INSERT INTO messages (chat_id, sender_id, text, reply_to_id, hidden_from)
        SELECT $1, $2, $3,
               (SELECT id FROM messages WHERE id = $4::bigint AND chat_id = $1),${blockedMembersOf('$1', '$2')}
        WHERE EXISTS (
          SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2
        )
        RETURNING *
      )
      SELECT ${messageColumns('$2')}
      FROM m
      ${replyJoins('$2')}
    `,
      [chatId, senderId, text, replyToId ?? null]
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
    fileSize: number,
    replyToId?: number | null
  ) {
    const result = await db.query(
      `
      WITH m AS (
        INSERT INTO messages (
          chat_id, sender_id,
          file_url, file_type, original_name, mime_type, file_size, reply_to_id,
          hidden_from
        )
        SELECT $1, $2, $3, $4, $5, $6, $7,
               (SELECT id FROM messages WHERE id = $8::bigint AND chat_id = $1),${blockedMembersOf('$1', '$2')}
        WHERE EXISTS (
          SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2
        )
        RETURNING *
      )
      SELECT ${messageColumns('$2')}
      FROM m
      ${replyJoins('$2')}
    `,
      [chatId, senderId, fileUrl, fileType, originalName, mimeType, fileSize, replyToId ?? null]
    );
    return result.rows[0] ?? null;
  },

  async createChat(userId: number, contactId: number) {
    if (userId === contactId) {
      throw new ChatError(400, "Cannot create chat with yourself");
    }

    const client = await db.connect();
    try {
      await client.query("BEGIN");

      // Serialise concurrent "open chat" taps for the same pair of users so
      // they can't both miss the existence check and create two chats.
      await client.query(`SELECT pg_advisory_xact_lock($1, $2)`, [
        Math.min(userId, contactId),
        Math.max(userId, contactId),
      ]);

      const target = await client.query(`SELECT 1 FROM users WHERE id = $1`, [contactId]);
      if (target.rowCount === 0) {
        throw new ChatError(404, "User not found");
      }

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
      if (!(err instanceof ChatError)) console.error("DB ERROR createChat:", err);
      throw err;
    } finally {
      client.release();
    }
  },

  async createGroupChat(
    creatorId: number,
    name: string,
    memberIds: number[],
    avatar?: string | null
  ) {
    const client = await db.connect();
    try {
      await client.query("BEGIN");

      // Drop ids that don't exist, and anyone who has a block with the
      // creator (you can't pull someone who blocked you into a group).
      const eligible = await client.query(
        `SELECT u.id FROM users u
         WHERE u.id = ANY($1::bigint[])
           AND NOT EXISTS (
             SELECT 1 FROM contacts c
             WHERE ((c.user_id = $2 AND c.contact_user_id = u.id)
                OR (c.user_id = u.id AND c.contact_user_id = $2))
               AND c.status = 'blocked'
           )`,
        [memberIds, creatorId]
      );
      const others: number[] = eligible.rows
        .map((r: any) => Number(r.id))
        .filter((id: number) => id !== creatorId);

      if (others.length === 0) {
        throw new ChatError(400, "A group needs at least one other valid member");
      }

      const chat = await client.query(
        `
        INSERT INTO chats (name, type, created_by, avatar)
        VALUES ($1, 'group', $2, $3)
        RETURNING id
      `,
        [name, creatorId, avatar ?? null]
      );

      const chatId = chat.rows[0].id;
      const allMembers = [creatorId, ...others];

      await client.query(
        `INSERT INTO chat_members (chat_id, user_id)
         SELECT $1, UNNEST($2::bigint[])`,
        [chatId, allMembers]
      );

      await client.query("COMMIT");
      return { id: chatId, memberIds: allMembers };
    } catch (err) {
      await client.query("ROLLBACK");
      if (!(err instanceof ChatError)) console.error("DB ERROR createGroupChat:", err);
      throw err;
    } finally {
      client.release();
    }
  },

  /** Any current member of a GROUP may add people. */
  async addMemberToGroup(chatId: number, requesterId: number, userId: number) {
    const chat = await db.query(
      `SELECT c.type,
              EXISTS (SELECT 1 FROM chat_members WHERE chat_id = c.id AND user_id = $2) AS is_member
       FROM chats c WHERE c.id = $1`,
      [chatId, requesterId]
    );
    const row = chat.rows[0];
    // Same answer for "doesn't exist" and "not yours" so chat ids can't be probed
    if (!row || !row.is_member) throw new ChatError(404, "Chat not found");
    if (row.type !== "group") throw new ChatError(400, "Members can only be added to group chats");

    const target = await db.query(
      `SELECT 1 FROM users u
       WHERE u.id = $1
         AND NOT EXISTS (
           SELECT 1 FROM contacts c
           WHERE ((c.user_id = $2 AND c.contact_user_id = u.id)
              OR (c.user_id = u.id AND c.contact_user_id = $2))
             AND c.status = 'blocked'
         )`,
      [userId, requesterId]
    );
    if (target.rowCount === 0) throw new ChatError(404, "User not found");

    const result = await db.query(
      `
      INSERT INTO chat_members (chat_id, user_id, last_read_message_id)
      SELECT $1, $2, (SELECT MAX(id) FROM messages WHERE chat_id = $1)
      WHERE NOT EXISTS (
        SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2
      )
      RETURNING chat_id AS "chatId", user_id AS "userId"
    `,
      [chatId, userId]
    );
    return result.rows[0] ?? { chatId, userId };
  },

  /** The creator may remove anyone; everybody else may only remove themselves (leave). */
  async removeMemberFromGroup(chatId: number, requesterId: number, userId: number) {
    const chat = await db.query(
      `SELECT c.type, c.created_by,
              EXISTS (SELECT 1 FROM chat_members WHERE chat_id = c.id AND user_id = $2) AS is_member
       FROM chats c WHERE c.id = $1`,
      [chatId, requesterId]
    );
    const row = chat.rows[0];
    if (!row || !row.is_member) throw new ChatError(404, "Chat not found");
    if (row.type !== "group") throw new ChatError(400, "This is not a group chat");

    const isCreator = Number(row.created_by) === requesterId;
    const isSelf = userId === requesterId;
    if (!isCreator && !isSelf) {
      throw new ChatError(403, "Only the group creator can remove other members");
    }
    if (isCreator && isSelf) {
      throw new ChatError(400, "The creator can't leave the group — delete it instead");
    }

    const result = await db.query(
      `
      DELETE FROM chat_members
      WHERE chat_id = $1 AND user_id = $2
      RETURNING chat_id AS "chatId", user_id AS "userId"
    `,
      [chatId, userId]
    );
    return result.rows[0] ?? null;
  },

  async updateGroupInfo(chatId: number, requesterId: number, name?: string, avatar?: string) {
    const fields: string[] = [];
    const values: any[] = [chatId, requesterId];
    let i = 3;

    if (name !== undefined) {
      fields.push(`name = $${i++}`);
      values.push(name);
    }
    if (avatar !== undefined) {
      fields.push(`avatar = $${i++}`);
      values.push(avatar);
    }
    if (fields.length === 0) throw new ChatError(400, "Nothing to update");

    const result = await db.query(
      `
      UPDATE chats SET ${fields.join(", ")}
      WHERE id = $1
        AND type = 'group'
        AND EXISTS (SELECT 1 FROM chat_members WHERE chat_id = $1 AND user_id = $2)
      RETURNING id, name, avatar, type
    `,
      values
    );
    if (!result.rows[0]) throw new ChatError(404, "Group not found");
    return result.rows[0];
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

  /**
   * "Delete" from the chat list.
   *  - private chat  → removed for both participants
   *  - group, creator → whole group removed
   *  - group, member  → the requester just leaves
   * Returns who must be told the chat is gone.
   */
  async deleteChat(chatId: number, requesterId: number): Promise<{ notifyUserIds: number[] }> {
    const client = await db.connect();
    try {
      await client.query("BEGIN");

      const chatResult = await client.query(
        `SELECT c.id, c.type, c.created_by,
                EXISTS (SELECT 1 FROM chat_members WHERE chat_id = c.id AND user_id = $2) AS is_member
         FROM chats c WHERE c.id = $1 FOR UPDATE OF c`,
        [chatId, requesterId]
      );
      const chat = chatResult.rows[0];
      if (!chat || !chat.is_member) throw new ChatError(404, "Chat not found");

      let notifyUserIds: number[];
      if (chat.type === "group" && Number(chat.created_by) !== requesterId) {
        await client.query(
          `DELETE FROM chat_members WHERE chat_id = $1 AND user_id = $2`,
          [chatId, requesterId]
        );
        notifyUserIds = [requesterId];
      } else {
        notifyUserIds = await deleteChatCascade(client, chatId);
      }

      await client.query("COMMIT");
      return { notifyUserIds };
    } catch (err) {
      await client.query("ROLLBACK");
      if (!(err instanceof ChatError)) console.error("DB ERROR deleteChat:", err);
      throw err;
    } finally {
      client.release();
    }
  },

  /**
   * Adds, replaces or removes `userId`'s reaction on a message (one per person,
   * Telegram-style). Tapping the emoji that is already there removes it.
   *
   * Returns the message's full reaction list plus the members who may be told
   * about it — or `null` when the user may not touch that message at all
   * (not a member, or it was hidden from them by a block).
   */
  async setReaction(messageId: number, userId: number, emoji: string) {
    const client = await db.connect();
    try {
      await client.query("BEGIN");

      const target = await client.query(
        `SELECT m.chat_id AS "chatId"
           FROM messages m
           JOIN chat_members cm ON cm.chat_id = m.chat_id AND cm.user_id = $2
          WHERE m.id = $1
            AND NOT ${hiddenFrom('m', '$2')}`,
        [messageId, userId]
      );
      if (target.rowCount === 0) {
        await client.query("ROLLBACK");
        return null;
      }
      const chatId = Number(target.rows[0].chatId);

      const existing = await client.query(
        `SELECT emoji FROM message_reactions
          WHERE message_id = $1 AND user_id = $2
          FOR UPDATE`,
        [messageId, userId]
      );
      const current = existing.rows[0]?.emoji ?? null;

      if (current === emoji) {
        await client.query(
          `DELETE FROM message_reactions WHERE message_id = $1 AND user_id = $2`,
          [messageId, userId]
        );
      } else {
        await client.query(
          `INSERT INTO message_reactions (message_id, user_id, emoji)
           VALUES ($1, $2, $3)
           ON CONFLICT (message_id, user_id)
           DO UPDATE SET emoji = EXCLUDED.emoji, created_at = NOW()`,
          [messageId, userId, emoji]
        );
      }

      const reactions = await client.query(
        `SELECT user_id AS "userId", emoji
           FROM message_reactions
          WHERE message_id = $1
          ORDER BY created_at`,
        [messageId]
      );

      // Everyone who can see the message. The caller filters each recipient's
      // copy of the list (you never see a reaction from someone you block).
      const recipients = await client.query(
        `SELECT cm.user_id AS "userId"
           FROM chat_members cm
           JOIN messages m ON m.id = $1
          WHERE cm.chat_id = m.chat_id
            AND NOT (cm.user_id::bigint = ANY(m.hidden_from))`,
        [messageId]
      );

      await client.query("COMMIT");
      return {
        chatId,
        removed: current === emoji,
        reactions: reactions.rows as { userId: number; emoji: string }[],
        recipientIds: recipients.rows.map((r: any) => Number(r.userId)),
      };
    } catch (err) {
      await client.query("ROLLBACK");
      console.error("DB ERROR setReaction:", err);
      throw err;
    } finally {
      client.release();
    }
  },

  /** Pairs of users with a block between them, among `userIds`. */
  async blockedPairs(userIds: number[]): Promise<Set<string>> {
    if (userIds.length < 2) return new Set();
    const result = await db.query(
      `SELECT user_id, contact_user_id FROM contacts
        WHERE status = 'blocked'
          AND user_id = ANY($1::bigint[])
          AND contact_user_id = ANY($1::bigint[])`,
      [userIds]
    );
    const pairs = new Set<string>();
    for (const row of result.rows) {
      const a = Number(row.user_id);
      const b = Number(row.contact_user_id);
      pairs.add(`${a}:${b}`);
      pairs.add(`${b}:${a}`);
    }
    return pairs;
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
        throw new ChatError(404, "Group not found");
      }

      const chat = chatResult.rows[0];
      if (chat.type !== "group") {
        throw new ChatError(400, "This is not a group chat");
      }
      if (Number(chat.created_by) !== requesterId) {
        throw new ChatError(403, "Only the group creator can delete the group");
      }

      const memberIds = await deleteChatCascade(client, chatId);

      await client.query("COMMIT");
      return { chatId, memberIds };
    } catch (err) {
      await client.query("ROLLBACK");
      if (!(err instanceof ChatError)) console.error("DB ERROR deleteGroup:", err);
      throw err;
    } finally {
      client.release();
    }
  },
};
