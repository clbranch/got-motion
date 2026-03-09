-- Ensure daily_steps can be read by other group members
ALTER TABLE public.daily_steps ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own daily_steps" ON public.daily_steps;
CREATE POLICY "Users can read their own daily_steps"
  ON public.daily_steps FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can read daily_steps of group members" ON public.daily_steps;
CREATE POLICY "Users can read daily_steps of group members"
  ON public.daily_steps FOR SELECT
  TO authenticated
  USING (
    user_id IN (
      SELECT gm2.user_id 
      FROM public.group_members gm1
      JOIN public.group_members gm2 ON gm1.group_id = gm2.group_id
      WHERE gm1.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can insert their own daily_steps" ON public.daily_steps;
CREATE POLICY "Users can insert their own daily_steps"
  ON public.daily_steps FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update their own daily_steps" ON public.daily_steps;
CREATE POLICY "Users can update their own daily_steps"
  ON public.daily_steps FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
