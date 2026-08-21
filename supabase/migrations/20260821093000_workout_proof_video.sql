-- Short video proof + keep photo; widen storage MIME types.

ALTER TABLE public.logged_workouts
  ADD COLUMN IF NOT EXISTS proof_video_url text;

UPDATE storage.buckets
SET
  file_size_limit = 15728640,
  allowed_mime_types = ARRAY[
    'image/jpeg',
    'image/png',
    'image/webp',
    'video/mp4',
    'video/quicktime'
  ]
WHERE id = 'workout-proofs';
