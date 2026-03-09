-- Update the trigger to ensure email is always populated from new.email (auth.users column) 
-- as well as raw_user_meta_data as fallback.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, display_name, updated_at)
  VALUES (
    new.id,
    coalesce(new.email, new.raw_user_meta_data->>'email'),
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    coalesce(new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'name'),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = coalesce(EXCLUDED.email, public.profiles.email),
    full_name = coalesce(EXCLUDED.full_name, public.profiles.full_name),
    display_name = coalesce(EXCLUDED.display_name, public.profiles.display_name),
    updated_at = now();
  RETURN new;
END;
$$;

-- Backfill emails for existing profiles if missing
UPDATE public.profiles p
SET email = coalesce(u.email, u.raw_user_meta_data->>'email', p.email)
FROM auth.users u
WHERE p.id = u.id AND (p.email IS NULL OR p.email = '');
