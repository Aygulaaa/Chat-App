-- =============================================================================
-- 001_message_replies.sql                                           REQUIRED
-- Adds "reply to a specific message".
--
-- HOW TO RUN: Supabase Dashboard → SQL Editor → paste this whole file → Run.
-- Run it BEFORE deploying the new backend. It is safe to run while the OLD
-- backend is live (it only adds a nullable column the old code ignores), and
-- safe to run more than once.
-- =============================================================================

-- 1. The column.
--    reply_to_id points at another row of the SAME table (the quoted message).
--    Its type is copied from messages.id, so this works whether your id is
--    INTEGER (serial) or BIGINT (bigserial / identity).
--
--    ON DELETE SET NULL: when the quoted message is deleted, replies to it are
--    kept and simply stop showing a quote. (The default, NO ACTION, would make
--    it impossible to delete any message that someone has replied to. CASCADE
--    would delete other people's replies. SET NULL is the behaviour you want.)
DO $$
DECLARE
  id_type text;
BEGIN
  SELECT format_type(a.atttypid, a.atttypmod)
    INTO id_type
    FROM pg_attribute a
   WHERE a.attrelid = 'public.messages'::regclass
     AND a.attname  = 'id';

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public'
       AND table_name   = 'messages'
       AND column_name  = 'reply_to_id'
  ) THEN
    EXECUTE format(
      'ALTER TABLE public.messages
         ADD COLUMN reply_to_id %s
         REFERENCES public.messages(id) ON DELETE SET NULL',
      id_type
    );
  END IF;
END $$;

-- 2. Index for the foreign key.
--    Every time a message is deleted Postgres must find the rows that reference
--    it (to SET NULL them). Without this index that is a full scan of the
--    messages table on EVERY delete. Partial (WHERE … IS NOT NULL) keeps it
--    tiny, because most messages are not replies.
CREATE INDEX IF NOT EXISTS idx_messages_reply_to_id
  ON public.messages (reply_to_id)
  WHERE reply_to_id IS NOT NULL;

-- 3. Verify — should return one row: reply_to_id | integer-or-bigint | YES
SELECT column_name, data_type, is_nullable
  FROM information_schema.columns
 WHERE table_schema = 'public'
   AND table_name   = 'messages'
   AND column_name  = 'reply_to_id';
