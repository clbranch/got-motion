-- Ensure group_members.group_id cascades when a group is deleted
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'group_members_group_id_fkey'
      AND conrelid = 'public.group_members'::regclass
  ) THEN
    ALTER TABLE public.group_members
      DROP CONSTRAINT group_members_group_id_fkey;
  END IF;
END $$;

ALTER TABLE public.group_members
  ADD CONSTRAINT group_members_group_id_fkey
  FOREIGN KEY (group_id)
  REFERENCES public.groups(id)
  ON DELETE CASCADE;
