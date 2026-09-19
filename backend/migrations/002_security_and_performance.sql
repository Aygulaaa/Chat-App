-- =============================================================================
-- 002_security_and_performance.sql                     STRONGLY RECOMMENDED
--
-- Nothing in the new code depends on this file, but section 1 closes what is
-- potentially the biggest hole in the whole project. Safe to run repeatedly.
-- Read the comments: a few statements can fail if your data already violates
-- the rule they add — each one says what to do in that case.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. ROW LEVEL SECURITY  ← most important part of this file
-- -----------------------------------------------------------------------------
-- Supabase automatically exposes every table in the `public` schema through a
-- REST API at https://<project>.supabase.co/rest/v1/<table>. Anyone holding the
-- project's ANON key can call it — and the anon key is NOT a secret (yours is
-- sitting, commented out, in frontend/.env, which is bundled into the app).
--
-- With RLS DISABLED on a table, that API returns every row to anyone:
-- password hashes, session token hashes, every private message.
--
-- Your Node backend is not affected by RLS: it connects as the `postgres` role,
-- which owns the tables, and owners bypass RLS. So we enable RLS and add NO
-- policies = "deny everything that comes through the public API".
--
-- Check the current state first (Dashboard → Table Editor shows an
-- "RLS disabled" badge), or run:
--   SELECT relname, relrowsecurity FROM pg_class
--    WHERE relnamespace = 'public'::regnamespace AND relkind = 'r';
ALTER TABLE public.users          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_sessions  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_settings  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_members   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contacts       ENABLE ROW LEVEL SECURITY;

-- Belt and braces: the API roles get no table privileges at all.
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES    FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon, authenticated;

-- AFTER running this, restart the backend and send a message. If the backend
-- suddenly gets "permission denied" or empty results, your DATABASE_URL is not
-- using the table-owner role — tell me and we'll add a policy for that role.


-- -----------------------------------------------------------------------------
-- 2. UNIQUENESS the code already assumes
-- -----------------------------------------------------------------------------
-- a) One row per (chat, user). The backend's queries are littered with
--    SELECT DISTINCT to paper over duplicates; this makes them impossible.
--    If it fails with "could not create unique index", remove duplicates first:
--      DELETE FROM chat_members a USING chat_members b
--       WHERE a.ctid < b.ctid AND a.chat_id = b.chat_id AND a.user_id = b.user_id;
CREATE UNIQUE INDEX IF NOT EXISTS uq_chat_members_chat_user
  ON public.chat_members (chat_id, user_id);

-- b) One contacts row per direction. addContact/blockUser do "UPDATE, and if
--    nothing was updated, INSERT" — two fast taps can insert two rows.
--    If it fails, dedupe first:
--      DELETE FROM contacts a USING contacts b
--       WHERE a.ctid < b.ctid AND a.user_id = b.user_id
--         AND a.contact_user_id = b.contact_user_id;
CREATE UNIQUE INDEX IF NOT EXISTS uq_contacts_pair
  ON public.contacts (user_id, contact_user_id);

-- c) Usernames. Login lowercases what the user types, so "Bob" and "bob" must
--    not both exist. You very likely already have UNIQUE(username); this adds
--    the case-insensitive version. If it fails you have two accounts whose
--    names differ only by case — rename one, then re-run.
CREATE UNIQUE INDEX IF NOT EXISTS uq_users_username_lower
  ON public.users (LOWER(username));

-- d) Session lookups happen on EVERY request, by token_hash.
CREATE UNIQUE INDEX IF NOT EXISTS uq_user_sessions_token_hash
  ON public.user_sessions (token_hash);


-- -----------------------------------------------------------------------------
-- 3. INDEXES for the hot queries
-- -----------------------------------------------------------------------------
-- Message history: WHERE chat_id = ? AND id < ? ORDER BY id DESC LIMIT 50
CREATE INDEX IF NOT EXISTS idx_messages_chat_id_id
  ON public.messages (chat_id, id DESC);

-- Chat list "last message": WHERE chat_id = ? ORDER BY created_at DESC LIMIT 1
CREATE INDEX IF NOT EXISTS idx_messages_chat_created
  ON public.messages (chat_id, created_at DESC);

-- Unread badge: WHERE chat_id = ? AND read_at IS NULL
CREATE INDEX IF NOT EXISTS idx_messages_chat_unread
  ON public.messages (chat_id, sender_id)
  WHERE read_at IS NULL;

-- "Mark delivered on connect": WHERE delivered_at IS NULL
CREATE INDEX IF NOT EXISTS idx_messages_undelivered
  ON public.messages (chat_id)
  WHERE delivered_at IS NULL;

-- "Which chats am I in?"
CREATE INDEX IF NOT EXISTS idx_chat_members_user
  ON public.chat_members (user_id);

-- Block checks run in BOTH directions inside almost every message query.
-- uq_contacts_pair covers (user_id, contact_user_id); this covers the reverse.
CREATE INDEX IF NOT EXISTS idx_contacts_reverse
  ON public.contacts (contact_user_id, user_id)
  WHERE status = 'blocked';

-- Sessions screen + "log out other devices"
CREATE INDEX IF NOT EXISTS idx_user_sessions_user
  ON public.user_sessions (user_id);

-- Push-token ownership ("this device now belongs to another account")
CREATE INDEX IF NOT EXISTS idx_users_fcm_token
  ON public.users (fcm_token)
  WHERE fcm_token IS NOT NULL;

-- User search uses  username ILIKE '%term%'  which no normal index can serve.
-- pg_trgm makes it fast. (Supabase keeps extensions in the `extensions` schema.)
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;
CREATE INDEX IF NOT EXISTS idx_users_username_trgm
  ON public.users USING gin (username extensions.gin_trgm_ops);


-- -----------------------------------------------------------------------------
-- 4. DATA RULES enforced by the database, not just the API
-- -----------------------------------------------------------------------------
-- NOT VALID = applies to new/updated rows only, so existing data can't make
-- these statements fail.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'messages_text_length') THEN
    ALTER TABLE public.messages
      ADD CONSTRAINT messages_text_length
      CHECK (text IS NULL OR char_length(text) <= 4000) NOT VALID;
  END IF;

  -- A message must carry something: text or a file.
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'messages_has_content') THEN
    ALTER TABLE public.messages
      ADD CONSTRAINT messages_has_content
      CHECK (text IS NOT NULL OR file_url IS NOT NULL) NOT VALID;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'contacts_not_self') THEN
    ALTER TABLE public.contacts
      ADD CONSTRAINT contacts_not_self
      CHECK (user_id <> contact_user_id) NOT VALID;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'user_settings_theme_valid') THEN
    ALTER TABLE public.user_settings
      ADD CONSTRAINT user_settings_theme_valid
      CHECK (theme IN ('light', 'dark')) NOT VALID;
  END IF;
END $$;


-- -----------------------------------------------------------------------------
-- 5. OPTIONAL — purge dead sessions nightly
-- -----------------------------------------------------------------------------
-- The backend now refuses sessions idle for 60+ days, but the rows stay in the
-- table forever. To clean them up automatically, enable the pg_cron extension
-- (Dashboard → Database → Extensions → pg_cron) and then run:
--
--   SELECT cron.schedule(
--     'purge-dead-sessions', '0 3 * * *',
--     $$DELETE FROM public.user_sessions
--        WHERE COALESCE(last_active_at, created_at) < NOW() - INTERVAL '60 days'$$
--   );
