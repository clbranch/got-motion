-- Fix new-user group creation and daily steps upsert conflicts.
-- 1) group_members.user_id must reference auth.users(id)
-- 2) daily_steps upsert(onConflict: user_id,date) requires a unique constraint

DO $$
BEGIN
  -- Drop legacy FK if it exists (often points to public.users).
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'group_members_user_id_fkey'
      AND conrelid = 'public.group_members'::regclass
  ) THEN
    ALTER TABLE public.group_members
      DROP CONSTRAINT group_members_user_id_fkey;
  END IF;
END $$;

-- Remove orphan memberships left by legacy foreign-key wiring.
DELETE FROM public.group_members gm
WHERE NOT EXISTS (
  SELECT 1
  FROM auth.users u
  WHERE u.id = gm.user_id
);

DO $$
BEGIN
  -- Ensure group_members.user_id references auth.users after orphan cleanup.
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'group_members_user_id_fkey'
      AND conrelid = 'public.group_members'::regclass
  ) THEN
    ALTER TABLE public.group_members
      ADD CONSTRAINT group_members_user_id_fkey
      FOREIGN KEY (user_id)
      REFERENCES auth.users(id)
      ON DELETE CASCADE;
  END IF;
END $$;

-- Remove duplicate daily_steps rows so unique(user_id, date) can be added safely.
DELETE FROM public.daily_steps d
USING public.daily_steps d2
WHERE d.user_id = d2.user_id
  AND d.date = d2.date
  AND d.ctid < d2.ctid;

DO $$
BEGIN
  -- Required for upsert(onConflict: 'user_id,date') in app code.
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'daily_steps_user_id_date_key'
      AND conrelid = 'public.daily_steps'::regclass
  ) THEN
    ALTER TABLE public.daily_steps
      ADD CONSTRAINT daily_steps_user_id_date_key
      UNIQUE (user_id, date);
  END IF;
END $$;
