-- Group creators can remove members. Members can still remove themselves.

CREATE OR REPLACE FUNCTION public.is_group_creator(target_group_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.groups
    WHERE id = target_group_id
      AND created_by = auth.uid()
  );
$$;

REVOKE ALL ON FUNCTION public.is_group_creator(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_group_creator(uuid) TO authenticated;

DROP POLICY IF EXISTS "Users can leave groups" ON public.group_members;
DROP POLICY IF EXISTS "Creators can remove group members" ON public.group_members;

CREATE POLICY "Members can leave and creators can remove members"
  ON public.group_members FOR DELETE
  TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_group_creator(group_id)
  );
