import type { Server } from "socket.io";
import type { PoolClient } from "pg";
import { db } from "../../db";

/**
 * Delivered / read receipts — per message AND per recipient.
 *
 *  message_receipts(message_id, user_id, delivered_at, read_at)
 *      the truth: what each recipient has received / opened.
 *  chat_members.last_read_message_id
 *      per-member "read up to here" pointer → cheap unread badges.
 *  messages.delivered_at / messages.read_at
 *      aggregates: set once EVERY recipient has the receipt. They drive the
 *      sender's ✓✓ and blue ✓✓ (WhatsApp group semantics).
 *
 * Every function below returns the messages whose aggregate JUST flipped, so
 * callers only notify senders about real changes.
 */

export interface FlippedMessage {
  id: number;
  chatId: number;
  senderId: number;
  at: Date;
}

/** true when `a` and `b` have a block between them in either direction */
const blockedBetween = (a: string, b: string) => `
  EXISTS (
    SELECT 1 FROM contacts bl
    WHERE ((bl.user_id = ${a} AND bl.contact_user_id = ${b})
        OR (bl.user_id = ${b} AND bl.contact_user_id = ${a}))
      AND bl.status = 'blocked'
  )`;

const toFlipped = (rows: any[]): FlippedMessage[] =>
  rows.map((r) => ({
    id: Number(r.id),
    chatId: Number(r.chat_id),
    senderId: Number(r.sender_id),
    at: r.at,
  }));

/** Marks `delivered_at` on messages that every (non-blocked) recipient now has. */
async function flipDelivered(client: PoolClient, messageIds: number[]) {
  if (messageIds.length === 0) return [];
  const result = await client.query(
    `UPDATE messages m
        SET delivered_at = NOW()
      WHERE m.id = ANY($1::bigint[])
        AND m.delivered_at IS NULL
        AND NOT EXISTS (
          SELECT 1 FROM chat_members cm
           WHERE cm.chat_id = m.chat_id
             AND cm.user_id <> m.sender_id
             AND NOT ${blockedBetween("cm.user_id", "m.sender_id")}
             AND NOT EXISTS (
               SELECT 1 FROM message_receipts r
                WHERE r.message_id = m.id
                  AND r.user_id = cm.user_id
                  AND r.delivered_at IS NOT NULL
             )
        )
      RETURNING m.id, m.chat_id, m.sender_id, m.delivered_at AS at`,
    [messageIds]
  );
  return toFlipped(result.rows);
}

/**
 * Marks `read_at` once every recipient WHO SHARES READ RECEIPTS has read it.
 * People who turned receipts off are left out of the requirement — and if
 * nobody is left (e.g. a 1-to-1 chat with such a person) the message never
 * turns blue, which is precisely what that privacy setting promises.
 */
async function flipRead(client: PoolClient, messageIds: number[]) {
  if (messageIds.length === 0) return [];
  const sharing = `
    cm.chat_id = m.chat_id
    AND cm.user_id <> m.sender_id
    AND NOT ${blockedBetween("cm.user_id", "m.sender_id")}
    AND NOT EXISTS (
      SELECT 1 FROM user_settings us
       WHERE us.user_id = cm.user_id AND us.hide_read_receipts = true
    )`;
  const result = await client.query(
    `UPDATE messages m
        SET read_at = NOW(),
            delivered_at = COALESCE(m.delivered_at, NOW())
      WHERE m.id = ANY($1::bigint[])
        AND m.read_at IS NULL
        AND EXISTS (SELECT 1 FROM chat_members cm WHERE ${sharing})
        AND NOT EXISTS (
          SELECT 1 FROM chat_members cm
           WHERE ${sharing}
             AND NOT EXISTS (
               SELECT 1 FROM message_receipts r
                WHERE r.message_id = m.id
                  AND r.user_id = cm.user_id
                  AND r.read_at IS NOT NULL
             )
        )
      RETURNING m.id, m.chat_id, m.sender_id, m.read_at AS at`,
    [messageIds]
  );
  return toFlipped(result.rows);
}

export const receipts = {
  /**
   * `userId`'s device has received messages. Scope with `chatId` (history was
   * fetched), `messageId` (one live message acknowledged) or neither (device
   * just came online → everything it is a recipient of).
   */
  async recordDelivered(
    userId: number,
    scope: { chatId?: number; messageId?: number } = {}
  ): Promise<FlippedMessage[]> {
    const client = await db.connect();
    try {
      await client.query("BEGIN");

      // `m.delivered_at IS NULL` keeps this on the small partial index of
      // not-yet-fully-delivered messages instead of the whole history.
      const recorded = await client.query(
        `INSERT INTO message_receipts (message_id, user_id, delivered_at)
         SELECT m.id, $1, NOW()
           FROM messages m
           JOIN chat_members me ON me.chat_id = m.chat_id AND me.user_id = $1
          WHERE m.sender_id <> $1
            AND m.delivered_at IS NULL
            AND ($2::bigint IS NULL OR m.chat_id = $2::bigint)
            AND ($3::bigint IS NULL OR m.id = $3::bigint)
            AND NOT ${blockedBetween("$1", "m.sender_id")}
         ON CONFLICT (message_id, user_id) DO UPDATE
            SET delivered_at = EXCLUDED.delivered_at
          WHERE message_receipts.delivered_at IS NULL
         RETURNING message_id`,
        [userId, scope.chatId ?? null, scope.messageId ?? null]
      );

      const flipped = await flipDelivered(
        client,
        recorded.rows.map((r: any) => Number(r.message_id))
      );
      await client.query("COMMIT");
      return flipped;
    } catch (err) {
      await client.query("ROLLBACK");
      throw err;
    } finally {
      client.release();
    }
  },

  /** `readerId` opened `chatId`: everything in it (from others) is now read by them. */
  async recordRead(
    readerId: number,
    chatId: number
  ): Promise<{ readIds: number[]; delivered: FlippedMessage[]; read: FlippedMessage[] }> {
    const client = await db.connect();
    try {
      await client.query("BEGIN");

      // Only messages past the reader's pointer can be unread → bounded scan.
      const recorded = await client.query(
        `INSERT INTO message_receipts (message_id, user_id, delivered_at, read_at)
         SELECT m.id, $1, NOW(), NOW()
           FROM messages m
           JOIN chat_members me ON me.chat_id = m.chat_id AND me.user_id = $1
          WHERE m.chat_id = $2
            AND m.sender_id <> $1
            AND m.id > COALESCE(me.last_read_message_id, 0)
            AND NOT ${blockedBetween("$1", "m.sender_id")}
         ON CONFLICT (message_id, user_id) DO UPDATE
            SET read_at = EXCLUDED.read_at,
                delivered_at = COALESCE(message_receipts.delivered_at, EXCLUDED.delivered_at)
          WHERE message_receipts.read_at IS NULL
         RETURNING message_id`,
        [readerId, chatId]
      );
      const readIds = recorded.rows.map((r: any) => Number(r.message_id));

      await client.query(
        `UPDATE chat_members cm
            SET last_read_message_id = GREATEST(
                  COALESCE(cm.last_read_message_id, 0),
                  COALESCE((SELECT MAX(id) FROM messages WHERE chat_id = $2), 0))
          WHERE cm.chat_id = $2 AND cm.user_id = $1`,
        [readerId, chatId]
      );

      const delivered = await flipDelivered(client, readIds);
      const read = await flipRead(client, readIds);

      await client.query("COMMIT");
      return { readIds, delivered, read };
    } catch (err) {
      await client.query("ROLLBACK");
      throw err;
    } finally {
      client.release();
    }
  },

  /**
   * Who has received / read one message — for "Message Info". Only the sender
   * may ask. Read times are withheld for members who hide receipts, and
   * entirely if the sender hides theirs (the setting is reciprocal).
   */
  async getMessageReceipts(messageId: number, requesterId: number) {
    const result = await db.query(
      `SELECT u.id       AS "userId",
              u.username,
              u.avatar,
              r.delivered_at AS "deliveredAt",
              CASE
                WHEN COALESCE(their.hide_read_receipts, false)
                  OR COALESCE(mine.hide_read_receipts, false) THEN NULL
                ELSE r.read_at
              END AS "readAt"
         FROM messages m
         JOIN chat_members cm ON cm.chat_id = m.chat_id AND cm.user_id <> m.sender_id
         JOIN users u ON u.id = cm.user_id
         LEFT JOIN message_receipts r ON r.message_id = m.id AND r.user_id = cm.user_id
         LEFT JOIN user_settings their ON their.user_id = cm.user_id
         LEFT JOIN user_settings mine  ON mine.user_id = $2
        WHERE m.id = $1
          AND m.sender_id = $2
          AND NOT ${blockedBetween("cm.user_id", "m.sender_id")}
        ORDER BY r.read_at NULLS LAST, r.delivered_at NULLS LAST, u.username`,
      [messageId, requesterId]
    );
    return result.rows;
  },

  // ── Realtime fan-out ──────────────────────────────────────────────────────

  /** Tells each sender which of THEIR messages are now delivered to everyone. */
  emitDelivered(io: Server | null | undefined, flipped: FlippedMessage[]) {
    if (!io || flipped.length === 0) return;
    // One event per (sender, chat). The old code grouped by sender only and
    // stamped every message with the first chat's id.
    const groups = new Map<string, FlippedMessage[]>();
    for (const f of flipped) {
      const key = `${f.senderId}:${f.chatId}`;
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key)!.push(f);
    }
    for (const group of groups.values()) {
      const first = group[0]!;
      io.to(`user_${first.senderId}`).emit("messages_delivered", {
        chatId: first.chatId,
        messageIds: group.map((g) => g.id),
        deliveredAt: first.at,
      });
    }
  },

  /**
   * After `readerId` opened a chat:
   *  • the reader's own devices get `chat_read` (readBy = reader) so every
   *    device clears its unread badge;
   *  • each sender gets `chat_read` for the messages now read by everyone —
   *    unless that sender hides read receipts themselves (reciprocity).
   */
  async emitRead(
    io: Server | null | undefined,
    readerId: number,
    chatId: number,
    outcome: { readIds: number[]; delivered: FlippedMessage[]; read: FlippedMessage[] }
  ) {
    if (!io) return;
    this.emitDelivered(io, outcome.delivered);

    if (outcome.readIds.length > 0) {
      io.to(`user_${readerId}`).emit("chat_read", {
        chatId,
        readBy: readerId,
        messageIds: outcome.readIds,
        self: true,
      });
    }
    if (outcome.read.length === 0) return;

    const senderIds = [...new Set(outcome.read.map((f) => f.senderId))];
    const hidden = await db.query(
      `SELECT user_id FROM user_settings
        WHERE user_id = ANY($1::bigint[]) AND hide_read_receipts = true`,
      [senderIds]
    );
    const hiding = new Set(hidden.rows.map((r: any) => Number(r.user_id)));

    for (const senderId of senderIds) {
      if (hiding.has(senderId)) continue;
      const mine = outcome.read.filter((f) => f.senderId === senderId);
      io.to(`user_${senderId}`).emit("chat_read", {
        chatId,
        readBy: readerId,
        messageIds: mine.map((f) => f.id),
        readAt: mine[0]!.at,
      });
    }
  },
};
