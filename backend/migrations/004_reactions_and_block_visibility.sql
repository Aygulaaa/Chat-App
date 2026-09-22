-- =============================================================================
-- 004_reactions_and_block_visibility.sql                            REQUIRED
--
-- 1. message_reactions — emoji reactions shown on the corner of a bubble.
--    Before this, the emoji strip in the long-press menu sent the emoji as a
--    brand-new chat message.
--
-- 2. messages.hidden_from — who a message must NEVER reach.
--    Blocks were only checked live ("is there a block right now?"). The moment
--    you unblocked someone, everything they had sent while blocked turned into
--    ordinary messages: marked delivered, then read, without you ever having
--    been shown them. Now the block is recorded on the message when it is
--    sent, so it stays undelivered for good (Telegram behaviour): the sender
--    keeps a single tick, the blocker never sees it.
--    Messages sent before this migration carry no such record and keep the
--    old behaviour.
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

  -- One reaction per (message, user): picking another emoji replaces it,
  -- picking the same one again removes it.
  -- ON DELETE CASCADE: deleting a message (or an account) removes its
  -- reactions automatically.
  EXECUTE format($sql$
    CREATE TABLE IF NOT EXISTS public.message_reactions (
      message_id %s NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
      user_id    %s NOT NULL REFERENCES public.users(id)    ON DELETE CASCADE,
      emoji      text NOT NULL CHECK (char_length(emoji) BETWEEN 1 AND 16),
      created_at timestamptz NOT NULL DEFAULT NOW(),
      PRIMARY KEY (message_id, user_id)
    )$sql$, msg_id_type, user_id_type);
END $$;

-- Lets "delete account" cascade without scanning the whole table
-- (the primary key already covers lookups by message).
CREATE INDEX IF NOT EXISTS idx_message_reactions_user
  ON public.message_reactions (user_id);

-- Same lock-down as every other table (see 002).
ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON public.message_reactions FROM anon;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    REVOKE ALL ON public.message_reactions FROM authenticated;
  END IF;
END $$;

-- Ids of the members who had a block with the sender when the message was
-- sent. A constant default makes this a metadata-only change (no table rewrite).
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS hidden_from bigint[] NOT NULL DEFAULT '{}';
