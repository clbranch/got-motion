-- Run after applying 20260310160000_fix_daily_steps_fk_and_users_sync.sql
-- 1) Confirm daily_steps.user_id references auth.users (not public.users)
-- 2) Confirm both auth users exist and (if public.users exists) are in it

-- daily_steps FK: should reference auth.users
SELECT
  c.conname AS constraint_name,
  c.confrelid::regclass AS references_table
FROM pg_constraint c
JOIN pg_class t ON c.conrelid = t.oid
WHERE t.relname = 'daily_steps'
  AND c.conname = 'daily_steps_user_id_fkey';
-- Expected: references_table = auth.users

-- Auth users (your two IDs should appear here)
SELECT id, email, created_at
FROM auth.users
WHERE id IN (
  '576e66cb-e7c7-4d95-be4d-d69bdbc27ed7',
  '190d4ec8-a5f0-4486-a5e3-8f40af741f8a'
)
ORDER BY id;

-- If public.users exists, both should have a row
SELECT id FROM public.users
WHERE id IN (
  '576e66cb-e7c7-4d95-be4d-d69bdbc27ed7',
  '190d4ec8-a5f0-4486-a5e3-8f40af741f8a'
)
ORDER BY id;
