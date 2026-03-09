-- Fix: daily_steps insert fails with "violates foreign key constraint daily_steps_user_id_fkey"
-- "Key is not present in table users" because daily_steps.user_id referenced public.users
-- and authenticated users (auth.users) were not synced into public.users.
--
-- Approach:
-- 1) Point daily_steps.user_id at auth.users(id) so app writes succeed (single source of truth).
-- 2) Keep public.users in sync for any other FKs: create if missing, backfill, trigger for new signups.

-- ---------------------------------------------------------------------------
-- 1) daily_steps: drop FK to public.users (if present), add FK to auth.users
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'daily_steps_user_id_fkey'
      AND conrelid = 'public.daily_steps'::regclass
  ) THEN
    ALTER TABLE public.daily_steps
      DROP CONSTRAINT daily_steps_user_id_fkey;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'daily_steps_user_id_fkey'
      AND conrelid = 'public.daily_steps'::regclass
  ) THEN
    ALTER TABLE public.daily_steps
      ADD CONSTRAINT daily_steps_user_id_fkey
      FOREIGN KEY (user_id)
      REFERENCES auth.users(id)
      ON DELETE CASCADE;
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 2) public.users: create if not exists (minimal id-only so other FKs are satisfied)
--    If the table already exists (e.g. with extra columns), skip creation.
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'users') THEN
    CREATE TABLE public.users (
      id uuid PRIMARY KEY
    );
    COMMENT ON TABLE public.users IS 'Legacy app user table; id synced from auth.users. Kept for any FKs that still reference it. Prefer profiles for app user data.';
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 3) Backfill public.users from auth.users (all current auth users)
--    Safe if table has extra columns: we only insert id.
-- ---------------------------------------------------------------------------
INSERT INTO public.users (id)
SELECT u.id FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM public.users pu WHERE pu.id = u.id);

-- ---------------------------------------------------------------------------
-- 4) Trigger: on auth signup, insert into public.users to avoid future FK gaps
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_auth_user_to_public_users()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id)
  VALUES (new.id)
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created_sync_public_users ON auth.users;
CREATE TRIGGER on_auth_user_created_sync_public_users
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_auth_user_to_public_users();

COMMENT ON FUNCTION public.sync_auth_user_to_public_users() IS 'Keeps public.users in sync with auth.users so any FKs to public.users remain valid.';
