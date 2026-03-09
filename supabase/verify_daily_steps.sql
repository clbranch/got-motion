-- Run this in the Supabase SQL Editor for the project you're viewing in the dashboard.
-- It checks: (1) unique constraint on (user_id, date), (2) RLS policies for daily_steps.

-- 1) Unique constraint (required for upsert onConflict: 'user_id,date')
SELECT conname AS constraint_name, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.daily_steps'::regclass
  AND contype = 'u';

-- 2) RLS policies on daily_steps
SELECT policyname, cmd, qual::text AS using_expr, with_check::text
FROM pg_policies
WHERE tablename = 'daily_steps';

-- 3) Today's rows (to verify writes)
SELECT id, user_id, date, steps, miles, active_calories, exercise_minutes, created_at
FROM public.daily_steps
WHERE date = current_date
ORDER BY user_id;
