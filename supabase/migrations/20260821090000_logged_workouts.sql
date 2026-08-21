-- Logged workouts started in Got Motion (writes to Apple Health / Health Connect too).
-- Optional proof photo for phone-only users who want group credibility.

CREATE TABLE IF NOT EXISTS public.logged_workouts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  group_id uuid REFERENCES public.groups (id) ON DELETE SET NULL,
  activity_type text NOT NULL,
  title text NOT NULL,
  started_at timestamptz NOT NULL,
  ended_at timestamptz NOT NULL,
  duration_seconds integer NOT NULL CHECK (duration_seconds > 0),
  proof_image_url text,
  health_written boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS logged_workouts_user_started_idx
  ON public.logged_workouts (user_id, started_at DESC);

CREATE INDEX IF NOT EXISTS logged_workouts_group_started_idx
  ON public.logged_workouts (group_id, started_at DESC)
  WHERE group_id IS NOT NULL;

ALTER TABLE public.logged_workouts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own logged workouts"
  ON public.logged_workouts;
CREATE POLICY "Users can read their own logged workouts"
  ON public.logged_workouts FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can read group mates logged workouts"
  ON public.logged_workouts;
CREATE POLICY "Users can read group mates logged workouts"
  ON public.logged_workouts FOR SELECT
  TO authenticated
  USING (
    group_id IS NOT NULL
    AND group_id IN (
      SELECT gm.group_id
      FROM public.group_members gm
      WHERE gm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can insert their own logged workouts"
  ON public.logged_workouts;
CREATE POLICY "Users can insert their own logged workouts"
  ON public.logged_workouts FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update their own logged workouts"
  ON public.logged_workouts;
CREATE POLICY "Users can update their own logged workouts"
  ON public.logged_workouts FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete their own logged workouts"
  ON public.logged_workouts;
CREATE POLICY "Users can delete their own logged workouts"
  ON public.logged_workouts FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Proof photos (public read; owner write under their user folder)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'workout-proofs',
  'workout-proofs',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Workout proofs are publicly readable" ON storage.objects;
CREATE POLICY "Workout proofs are publicly readable"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'workout-proofs');

DROP POLICY IF EXISTS "Users can upload workout proofs" ON storage.objects;
CREATE POLICY "Users can upload workout proofs"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'workout-proofs'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users can update their workout proofs" ON storage.objects;
CREATE POLICY "Users can update their workout proofs"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'workout-proofs'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'workout-proofs'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users can delete their workout proofs" ON storage.objects;
CREATE POLICY "Users can delete their workout proofs"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'workout-proofs'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
