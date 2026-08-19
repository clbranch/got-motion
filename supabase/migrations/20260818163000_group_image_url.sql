-- Group photos. Only the group admin (created_by) can set or change them.

ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS image_url text;

DROP POLICY IF EXISTS "Admins can update their groups" ON public.groups;
CREATE POLICY "Admins can update their groups"
  ON public.groups FOR UPDATE
  TO authenticated
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'group-avatars',
  'group-avatars',
  true,
  2097152,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Group avatars are publicly readable" ON storage.objects;
CREATE POLICY "Group avatars are publicly readable"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'group-avatars');

DROP POLICY IF EXISTS "Admins can upload group avatars" ON storage.objects;
CREATE POLICY "Admins can upload group avatars"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'group-avatars'
    AND EXISTS (
      SELECT 1
      FROM public.groups g
      WHERE g.id::text = (storage.foldername(name))[1]
        AND g.created_by = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Admins can update group avatars" ON storage.objects;
CREATE POLICY "Admins can update group avatars"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'group-avatars'
    AND EXISTS (
      SELECT 1
      FROM public.groups g
      WHERE g.id::text = (storage.foldername(name))[1]
        AND g.created_by = auth.uid()
    )
  )
  WITH CHECK (
    bucket_id = 'group-avatars'
    AND EXISTS (
      SELECT 1
      FROM public.groups g
      WHERE g.id::text = (storage.foldername(name))[1]
        AND g.created_by = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Admins can delete group avatars" ON storage.objects;
CREATE POLICY "Admins can delete group avatars"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'group-avatars'
    AND EXISTS (
      SELECT 1
      FROM public.groups g
      WHERE g.id::text = (storage.foldername(name))[1]
        AND g.created_by = auth.uid()
    )
  );
