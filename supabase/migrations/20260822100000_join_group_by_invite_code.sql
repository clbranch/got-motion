-- Join via shared invite code without requiring read access to groups first.
-- The app previously queried groups.invite_code directly, but RLS only allows
-- reading groups the user already belongs to (or has a pending email invite).

CREATE OR REPLACE FUNCTION public.join_group_by_invite_code(p_invite_code text)
RETURNS TABLE(group_id uuid, group_name text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_code text := upper(trim(p_invite_code));
  v_group_id uuid;
  v_group_name text;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF v_code IS NULL OR v_code = '' THEN
    RAISE EXCEPTION 'Invite code is required';
  END IF;

  SELECT g.id, g.name
  INTO v_group_id, v_group_name
  FROM public.groups g
  WHERE g.invite_code = v_code
  LIMIT 1;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Invalid invite code';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.group_members gm
    WHERE gm.user_id = v_user_id
      AND gm.group_id = v_group_id
  ) THEN
    RAISE EXCEPTION 'Already in group';
  END IF;

  INSERT INTO public.group_members (user_id, group_id)
  VALUES (v_user_id, v_group_id);

  group_id := v_group_id;
  group_name := coalesce(v_group_name, 'Group');
  RETURN NEXT;
END;
$$;

REVOKE ALL ON FUNCTION public.join_group_by_invite_code(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.join_group_by_invite_code(text) TO authenticated;
