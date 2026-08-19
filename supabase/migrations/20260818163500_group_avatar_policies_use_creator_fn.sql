-- Group avatar storage rules re-queried public.groups, which has its own RLS.
-- Use the existing SECURITY DEFINER creator check so the policy cannot be
-- blocked by the caller's read permissions on groups.

CREATE OR REPLACE FUNCTION public.is_group_avatar_admin(object_name text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  folder text;
  group_uuid uuid;
BEGIN
  folder := (storage.foldername(object_name))[1];
  IF folder IS NULL THEN
    RETURN false;
  END IF;

  BEGIN
    group_uuid := folder::uuid;
  EXCEPTION WHEN others THEN
    RETURN false;
  END;

  RETURN EXISTS (
    SELECT 1
    FROM public.groups
    WHERE id = group_uuid
      AND created_by = auth.uid()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.is_group_avatar_admin(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_group_avatar_admin(text) TO authenticated;

DROP POLICY IF EXISTS "Admins can upload group avatars" ON storage.objects;
CREATE POLICY "Admins can upload group avatars"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'group-avatars'
    AND public.is_group_avatar_admin(name)
  );

DROP POLICY IF EXISTS "Admins can update group avatars" ON storage.objects;
CREATE POLICY "Admins can update group avatars"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'group-avatars'
    AND public.is_group_avatar_admin(name)
  )
  WITH CHECK (
    bucket_id = 'group-avatars'
    AND public.is_group_avatar_admin(name)
  );

DROP POLICY IF EXISTS "Admins can delete group avatars" ON storage.objects;
CREATE POLICY "Admins can delete group avatars"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'group-avatars'
    AND public.is_group_avatar_admin(name)
  );

-- Uploading writes the row first, so the writer must be able to read it back.
DROP POLICY IF EXISTS "Group avatars are publicly readable" ON storage.objects;
CREATE POLICY "Group avatars are publicly readable"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'group-avatars');

-- Group row update is what stores image_url; keep it admin-only.
DROP POLICY IF EXISTS "Admins can update their groups" ON public.groups;
CREATE POLICY "Admins can update their groups"
  ON public.groups FOR UPDATE
  TO authenticated
  USING (public.is_group_creator(id))
  WITH CHECK (public.is_group_creator(id));
