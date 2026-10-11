-- PRESSINGS_RLS_FIX.sql
-- Erreur: infinite recursion detected in policy for relation "pressings"
-- Supabase SQL Editor → coller → Run

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS 'SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role::text = ''admin'');';

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS 'SELECT role::text FROM public.profiles WHERE id = auth.uid() LIMIT 1;';

CREATE OR REPLACE FUNCTION public.my_pressing_ids()
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS 'SELECT id FROM public.pressings WHERE owner_profile_id = auth.uid();';

ALTER TABLE public.pressings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pressings_select" ON public.pressings;
DROP POLICY IF EXISTS "pressings_insert_own" ON public.pressings;
DROP POLICY IF EXISTS "pressings_update_own" ON public.pressings;
DROP POLICY IF EXISTS "pressings_delete_own" ON public.pressings;
DROP POLICY IF EXISTS "Pressings are viewable by everyone" ON public.pressings;
DROP POLICY IF EXISTS "Owners can insert pressings" ON public.pressings;
DROP POLICY IF EXISTS "Owners can update pressings" ON public.pressings;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.pressings;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.pressings;

CREATE POLICY "pressings_select" ON public.pressings
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "pressings_insert_own" ON public.pressings
  FOR INSERT TO authenticated
  WITH CHECK (owner_profile_id = auth.uid() OR public.is_admin());

CREATE POLICY "pressings_update_own" ON public.pressings
  FOR UPDATE TO authenticated
  USING (owner_profile_id = auth.uid() OR public.is_admin())
  WITH CHECK (owner_profile_id = auth.uid() OR public.is_admin());

CREATE POLICY "pressings_delete_own" ON public.pressings
  FOR DELETE TO authenticated
  USING (public.is_admin());

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "subs_insert" ON public.subscriptions;
DROP POLICY IF EXISTS "subs_all_owner" ON public.subscriptions;
DROP POLICY IF EXISTS "subs_select" ON public.subscriptions;

CREATE POLICY "subs_select" ON public.subscriptions
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "subs_insert" ON public.subscriptions
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "subs_all_owner" ON public.subscriptions
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
