-- Group invite system: table, constraints, RLS.
-- invited_by stores auth.uid(); invited_email can be any email (existing or future user).
-- Prevents duplicate pending invites per (group_id, invited_email). Prevents duplicate members on accept.

CREATE TABLE IF NOT EXISTS public.group_invites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  invited_email text NOT NULL,
  invited_by uuid NOT NULL,
  invite_token text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  accepted_at timestamptz NULL,
  CONSTRAINT group_invites_status_check CHECK (status IN ('pending', 'accepted', 'declined', 'revoked', 'expired'))
);

CREATE UNIQUE INDEX IF NOT EXISTS group_invites_invite_token_key ON public.group_invites (invite_token);
CREATE UNIQUE INDEX IF NOT EXISTS group_invites_pending_unique
  ON public.group_invites (group_id, lower(trim(invited_email)))
  WHERE status = 'pending';

COMMENT ON TABLE public.group_invites IS 'Email invites to groups; invite_token for future deep-link/signup flow.';

ALTER TABLE public.group_invites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can create invites for their groups" ON public.group_invites;
DROP POLICY IF EXISTS "Users can read invites they sent or received" ON public.group_invites;
DROP POLICY IF EXISTS "Invited user can update invite to accept or decline" ON public.group_invites;

CREATE POLICY "Users can create invites for their groups"
  ON public.group_invites FOR INSERT
  TO authenticated
  WITH CHECK (
    invited_by = auth.uid()
    AND group_id IN (SELECT public.current_user_group_ids())
  );

CREATE POLICY "Users can read invites they sent or received"
  ON public.group_invites FOR SELECT
  TO authenticated
  USING (
    invited_by = auth.uid()
    OR lower(trim(invited_email)) = lower(trim(auth.jwt() ->> 'email'))
  );

CREATE POLICY "Invited user can update invite to accept or decline"
  ON public.group_invites FOR UPDATE
  TO authenticated
  USING (lower(trim(invited_email)) = lower(trim(auth.jwt() ->> 'email')))
  WITH CHECK (true);

-- Allow users to read a group's name when they have a pending invite to it (for "X invited you" UI).
DROP POLICY IF EXISTS "Users can read groups they have pending invite to" ON public.groups;
CREATE POLICY "Users can read groups they have pending invite to"
  ON public.groups FOR SELECT
  TO authenticated
  USING (
    id IN (
      SELECT group_id FROM public.group_invites
      WHERE lower(trim(invited_email)) = lower(trim(coalesce(auth.jwt() ->> 'email', '')))
      AND status = 'pending'
    )
  );
