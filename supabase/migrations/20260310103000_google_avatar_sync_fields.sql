-- Add profile avatar sync metadata for Google-auth users.
-- avatar_source controls whether Google sync can overwrite avatar_url.

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS google_avatar_url text,
ADD COLUMN IF NOT EXISTS avatar_source text NOT NULL DEFAULT 'google',
ADD COLUMN IF NOT EXISTS google_avatar_last_synced_at timestamptz;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'profiles_avatar_source_check'
      AND conrelid = 'public.profiles'::regclass
  ) THEN
    ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_avatar_source_check
    CHECK (avatar_source IN ('google', 'custom'));
  END IF;
END $$;

-- Existing users with a non-empty avatar are treated as custom
-- so Google sync will not overwrite avatars they already set.
UPDATE public.profiles
SET avatar_source = 'custom'
WHERE coalesce(avatar_url, '') <> '';
