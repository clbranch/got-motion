-- The current group creator can transfer ownership to an existing member and
-- leave the group. The validation, update, and removal are one transaction.

CREATE OR REPLACE FUNCTION public.transfer_group_ownership_and_leave(
  target_group_id uuid,
  new_owner_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  current_owner_id uuid;
BEGIN
  SELECT created_by
  INTO current_owner_id
  FROM public.groups
  WHERE id = target_group_id
  FOR UPDATE;

  IF current_owner_id IS NULL OR current_owner_id <> auth.uid() THEN
    RAISE EXCEPTION 'Only the current group admin can transfer ownership.';
  END IF;

  IF new_owner_id = auth.uid() THEN
    RAISE EXCEPTION 'Choose another member as the new admin.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.group_members
    WHERE group_id = target_group_id
      AND user_id = new_owner_id
  ) THEN
    RAISE EXCEPTION 'The new admin must already belong to the group.';
  END IF;

  UPDATE public.groups
  SET created_by = new_owner_id
  WHERE id = target_group_id;

  DELETE FROM public.group_members
  WHERE group_id = target_group_id
    AND user_id = auth.uid();
END;
$$;

REVOKE ALL ON FUNCTION public.transfer_group_ownership_and_leave(uuid, uuid)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.transfer_group_ownership_and_leave(uuid, uuid)
  TO authenticated;
