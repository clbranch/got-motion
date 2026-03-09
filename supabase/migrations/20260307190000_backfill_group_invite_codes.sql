-- Backfill invite_code for groups that have NULL (e.g. created before column existed).
-- Each row gets a 6-char uppercase code derived from id so no collisions.

UPDATE public.groups
SET invite_code = upper(substring(replace(md5(id::text), '-', '') from 1 for 6))
WHERE invite_code IS NULL OR trim(invite_code) = '';
