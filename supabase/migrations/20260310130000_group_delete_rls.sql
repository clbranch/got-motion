-- Add DELETE policies for leaving groups and deleting groups

-- Allow users to remove their own group membership (leave group)
DROP POLICY IF EXISTS "Users can leave groups" ON public.group_members;
CREATE POLICY "Users can leave groups"
  ON public.group_members FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Allow creators to delete their groups
DROP POLICY IF EXISTS "Creators can delete their groups" ON public.groups;
CREATE POLICY "Creators can delete their groups"
  ON public.groups FOR DELETE
  TO authenticated
  USING (created_by = auth.uid());
