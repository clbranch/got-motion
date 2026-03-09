-- Fix create group / join group: allow authenticated users to insert into groups and group_members.
-- Run this migration against your linked project: supabase db push (or apply via Dashboard SQL editor).

-- Ensure invite_code exists on groups (required by app for create + join)
ALTER TABLE public.groups
  ADD COLUMN IF NOT EXISTS invite_code text;
CREATE UNIQUE INDEX IF NOT EXISTS groups_invite_code_key ON public.groups (invite_code) WHERE invite_code IS NOT NULL;

-- Enable RLS on both tables
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (so this migration is idempotent)
DROP POLICY IF EXISTS "Users can create groups" ON public.groups;
DROP POLICY IF EXISTS "Users can read groups they belong to" ON public.groups;
DROP POLICY IF EXISTS "Users can join groups" ON public.group_members;
DROP POLICY IF EXISTS "Users can read members of their groups" ON public.group_members;

-- groups: allow authenticated users to create a group (insert)
CREATE POLICY "Users can create groups"
  ON public.groups FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- groups: allow authenticated users to read groups they are a member of
CREATE POLICY "Users can read groups they belong to"
  ON public.groups FOR SELECT
  TO authenticated
  USING (
    id IN (
      SELECT group_id FROM public.group_members WHERE user_id = auth.uid()
    )
  );

-- group_members: allow authenticated users to add themselves (create or join)
CREATE POLICY "Users can join groups"
  ON public.group_members FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- group_members: allow authenticated users to read members of groups they're in
CREATE POLICY "Users can read members of their groups"
  ON public.group_members FOR SELECT
  TO authenticated
  USING (
    group_id IN (
      SELECT gm.group_id FROM public.group_members gm WHERE gm.user_id = auth.uid()
    )
  );
