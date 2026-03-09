-- Update the trigger to populate display_name from raw_user_meta_data
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
    new.raw_user_meta_data->>'email',
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

-- Backfill display_name for existing profiles if they have it in meta data but not in profiles
UPDATE public.profiles p
SET display_name = coalesce(u.raw_user_meta_data->>'display_name', u.raw_user_meta_data->>'name', p.display_name)
FROM auth.users u
WHERE p.id = u.id AND (p.display_name IS NULL OR p.display_name = '');
