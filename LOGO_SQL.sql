-- Logo + droits update pressings
ALTER TABLE public.pressings ADD COLUMN IF NOT EXISTS logo_url TEXT;

-- Politique update propriétaire (si RLS actif)
DROP POLICY IF EXISTS "p_update" ON public.pressings;
CREATE POLICY "p_update" ON public.pressings
  FOR UPDATE TO authenticated
  USING (owner_profile_id = auth.uid())
  WITH CHECK (owner_profile_id = auth.uid());
