-- Track when each daily_steps row was last written from a device Health sync.
ALTER TABLE public.daily_steps
  ADD COLUMN IF NOT EXISTS synced_at timestamptz;

UPDATE public.daily_steps
SET synced_at = COALESCE(synced_at, now())
WHERE synced_at IS NULL;

CREATE INDEX IF NOT EXISTS daily_steps_synced_at_idx
  ON public.daily_steps (synced_at DESC);
