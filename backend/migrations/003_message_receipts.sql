-- =============================================================================
-- 003_message_receipts.sql                                          REQUIRED
-- Delivered / read status per message AND per recipient.
--
-- WHY: `messages.delivered_at` / `messages.read_at` hold ONE value per message.
-- That is fine for a 1-to-1 chat, but in a group it means "somebody read it":
--   • the sender saw blue ticks as soon as the first member opened the chat;
--   • every OTHER member's unread badge dropped to 0 for messages they had
--     never opened (the badge counted `read_at IS NULL`).
--
-- HOW TO RUN: Supabase → SQL Editor → paste the whole file → Run.
-- Run BEFORE deploying the new backend. Safe while the old backend is live
-- (it only adds things the old code ignores) and safe to run twice.
-- =============================================================================

DO $$
DECLARE
  msg_id_type  text;
  user_id_type text;
BEGIN
  SELECT format_type(atttypid, atttypmod) INTO msg_id_type
    FROM pg_attribute WHERE attrelid = 'public.messages'::regclass AND attname = 'id';
  SELECT format_type(atttypid, atttypmod) INTO user_id_type
    FROM pg_attribute WHERE attrelid = 'public.users'::regclass AND attname = 'id';

  -- 1. One row per (message, recipient). The sender never has a row.
  --    A row is created the first time that recipient's device receives the
  --    message; read_at is filled in when they open the chat.
  --    ON DELETE CASCADE: deleting a message (or an account) removes its
  --    receipts automatically — nothing to clean up in application code.
  EXECUTE format($sql$
    CREATE TABLE IF NOT EXISTS public.message_receipts (
      message_id   %s NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
      user_id      %s NOT NULL REFERENCES public.users(id)    ON DELETE CASCADE,
      delivered_at timestamptz,
      read_at      timestamptz,
      PRIMARY KEY (message_id, user_id)
    )$sql$, msg_id_type, user_id_type);

  -- 2. Per-member "I have read up to here" pointer.
  --    Unread badge = messages with id > pointer. Counting that is one index
  --    range scan; counting "messages with no read receipt of mine" would be
  --    an anti-join over the whole history on every chat-list load.
  --    Deliberately NOT a foreign key: the pointed-at message may be deleted
  --    later and the pointer must survive that.
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'chat_members'
       AND column_name = 'last_read_message_id'
  ) THEN
    EXECUTE format(
      'ALTER TABLE public.chat_members ADD COLUMN last_read_message_id %s',
      msg_id_type);
  END IF;
END $$;

-- Lets "delete account" cascade without scanning the whole receipts table
-- (the primary key already covers lookups by message).
CREATE INDEX IF NOT EXISTS idx_message_receipts_user
  ON public.message_receipts (user_id);

-- 3. Same lock-down as every other table (see 002): the backend connects as
--    the table owner and bypasses RLS; the public REST API gets nothing.
ALTER TABLE public.message_receipts ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON public.message_receipts FROM anon;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    REVOKE ALL ON public.message_receipts FROM authenticated;
  END IF;
END $$;

-- 4. Backfill so existing chats keep their ticks and badges.
--    Best available reconstruction: a message already marked delivered/read is
--    treated as delivered/read by every CURRENT member other than its sender.
INSERT INTO public.message_receipts (message_id, user_id, delivered_at, read_at)
SELECT m.id, cm.user_id, COALESCE(m.delivered_at, m.read_at), m.read_at
  FROM public.messages m
  JOIN public.chat_members cm
    ON cm.chat_id = m.chat_id AND cm.user_id <> m.sender_id
 WHERE m.delivered_at IS NOT NULL OR m.read_at IS NOT NULL
ON CONFLICT (message_id, user_id) DO NOTHING;

UPDATE public.chat_members cm
   SET last_read_message_id = seen.max_id
  FROM (
    SELECT m.chat_id, mem.user_id, MAX(m.id) AS max_id
      FROM public.messages m
      JOIN public.chat_members mem
        ON mem.chat_id = m.chat_id AND mem.user_id <> m.sender_id
     WHERE m.read_at IS NOT NULL
     GROUP BY m.chat_id, mem.user_id
  ) seen
 WHERE seen.chat_id = cm.chat_id
   AND seen.user_id = cm.user_id
   AND cm.last_read_message_id IS NULL;

-- 5. Verify — expect the new table's row count and the new column.
SELECT (SELECT COUNT(*) FROM public.message_receipts) AS receipts,
       (SELECT COUNT(*) FROM information_schema.columns
         WHERE table_schema = 'public' AND table_name = 'chat_members'
           AND column_name = 'last_read_message_id') AS pointer_column_exists;

-- NOTE: messages.delivered_at / messages.read_at are KEPT. They now mean
-- "delivered to / read by EVERY recipient" — that is what drives the sender's
-- ✓✓ and blue ✓✓, exactly like WhatsApp groups.
