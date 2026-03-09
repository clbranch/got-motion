-- Profiles: one row per auth user. Populated on signup (email/password or OAuth).
-- Used for display name, username, avatar across app (group members, leaderboard, profile screen).

CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text,
  full_name text,
  username text,
  display_name text,
  avatar_url text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.profiles IS 'User profile; id matches auth.users. Filled by trigger on signup.';

-- RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Users can read and update their own profile
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
CREATE POLICY "Users can read own profile"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (id = auth.uid());

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- Users can read profiles of other users who share at least one group (for members list, leaderboard)
DROP POLICY IF EXISTS "Users can read profiles in same group" ON public.profiles;
CREATE POLICY "Users can read profiles in same group"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (
    id = auth.uid()
    OR id IN (
      SELECT gm2.user_id
      FROM public.group_members gm1
      JOIN public.group_members gm2 ON gm2.group_id = gm1.group_id
      WHERE gm1.user_id = auth.uid()
    )
  );

-- Trigger: create profile on auth.users insert (signup / OAuth)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, updated_at)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'email',
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = coalesce(EXCLUDED.email, public.profiles.email),
    full_name = coalesce(EXCLUDED.full_name, public.profiles.full_name),
    updated_at = now();
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Backfill profiles for existing auth.users that don't have a row yet
INSERT INTO public.profiles (id, email, full_name, updated_at)
SELECT id, raw_user_meta_data->>'email', coalesce(raw_user_meta_data->>'full_name', raw_user_meta_data->>'name'), now()
FROM auth.users
ON CONFLICT (id) DO UPDATE SET
  email = coalesce(EXCLUDED.email, public.profiles.email),
  full_name = coalesce(EXCLUDED.full_name, public.profiles.full_name),
  updated_at = now();
