-- Fix infinite recursion in RLS: policies were reading group_members inside a policy on group_members.
-- Use a SECURITY DEFINER function so the check bypasses RLS and breaks the cycle.

CREATE OR REPLACE FUNCTION public.current_user_group_ids()
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT group_id FROM public.group_members WHERE user_id = auth.uid();
$$;

-- Drop the SELECT policies that cause recursion
DROP POLICY IF EXISTS "Users can read groups they belong to" ON public.groups;
DROP POLICY IF EXISTS "Users can read members of their groups" ON public.group_members;

-- groups: SELECT using the function (no direct read of group_members in policy)
CREATE POLICY "Users can read groups they belong to"
  ON public.groups FOR SELECT
  TO authenticated
  USING (id IN (SELECT public.current_user_group_ids()));

-- group_members: SELECT using the same function (no self-reference in policy)
CREATE POLICY "Users can read members of their groups"
  ON public.group_members FOR SELECT
  TO authenticated
  USING (group_id IN (SELECT public.current_user_group_ids()));
