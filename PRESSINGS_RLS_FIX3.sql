-- PRESSINGS_RLS_FIX3.sql — SANS $$ ni DO (compatible copier-coller mobile)
-- Supabase SQL Editor → coller → Run

ALTER TABLE public.pressings DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "p_select" ON public.pressings;
DROP POLICY IF EXISTS "p_insert" ON public.pressings;
DROP POLICY IF EXISTS "p_update" ON public.pressings;
DROP POLICY IF EXISTS "p_delete" ON public.pressings;
DROP POLICY IF EXISTS "pressings_select" ON public.pressings;
DROP POLICY IF EXISTS "pressings_insert_own" ON public.pressings;
DROP POLICY IF EXISTS "pressings_update_own" ON public.pressings;
DROP POLICY IF EXISTS "pressings_delete_own" ON public.pressings;
DROP POLICY IF EXISTS "Pressings are viewable by everyone" ON public.pressings;
DROP POLICY IF EXISTS "Owners can insert pressings" ON public.pressings;
DROP POLICY IF EXISTS "Owners can update pressings" ON public.pressings;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.pressings;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.pressings;
DROP POLICY IF EXISTS "pressings_owner_all" ON public.pressings;
DROP POLICY IF EXISTS "pressings_admin_all" ON public.pressings;
DROP POLICY IF EXISTS "Allow authenticated insert" ON public.pressings;
DROP POLICY IF EXISTS "Allow owner update" ON public.pressings;
DROP POLICY IF EXISTS "Allow owner select" ON public.pressings;

DROP POLICY IF EXISTS "s_select" ON public.subscriptions;
DROP POLICY IF EXISTS "s_insert" ON public.subscriptions;
DROP POLICY IF EXISTS "s_update" ON public.subscriptions;
DROP POLICY IF EXISTS "subs_select" ON public.subscriptions;
DROP POLICY IF EXISTS "subs_insert" ON public.subscriptions;
DROP POLICY IF EXISTS "subs_all_owner" ON public.subscriptions;

DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update" ON public.profiles;
DROP POLICY IF EXISTS "profiles_select_own_or_admin" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS 'SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role::text = ''admin'');';

CREATE OR REPLACE FUNCTION public.my_pressing_ids()
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS 'SELECT id FROM public.pressings WHERE owner_profile_id = auth.uid();';

ALTER TABLE public.pressings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "p_select" ON public.pressings
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "p_insert" ON public.pressings
  FOR INSERT TO authenticated
  WITH CHECK (owner_profile_id = auth.uid());

CREATE POLICY "p_update" ON public.pressings
  FOR UPDATE TO authenticated
  USING (owner_profile_id = auth.uid())
  WITH CHECK (owner_profile_id = auth.uid());

CREATE POLICY "p_delete" ON public.pressings
  FOR DELETE TO authenticated
  USING (owner_profile_id = auth.uid());

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "s_select" ON public.subscriptions
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "s_insert" ON public.subscriptions
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "s_update" ON public.subscriptions
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select" ON public.profiles
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "profiles_insert" ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());

CREATE POLICY "profiles_update" ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());
