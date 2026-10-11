-- PRESSINGS_RLS_FIX2.sql — version radicale
-- Supprime TOUTES les politiques sur pressings puis recrée des règles simples
-- Supabase SQL Editor → Run

-- 1) Désactiver RLS le temps de nettoyer
ALTER TABLE public.pressings DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions DISABLE ROW LEVEL SECURITY;

-- 2) Supprimer toutes les politiques existantes sur pressings
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'pressings'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.pressings', r.policyname);
  END LOOP;
END $$;

-- 3) Supprimer toutes les politiques sur subscriptions
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'subscriptions'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.subscriptions', r.policyname);
  END LOOP;
END $$;

-- 4) Fonctions sans boucle (SECURITY DEFINER = ne repasse pas par RLS)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role::text = 'admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.my_pressing_ids()
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM public.pressings WHERE owner_profile_id = auth.uid();
$$;

-- 5) Réactiver RLS avec politiques simples (aucune sous-requête sur pressings)
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

-- 6) Subscriptions ouvertes (création essai 30j)
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "s_select" ON public.subscriptions
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "s_insert" ON public.subscriptions
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "s_update" ON public.subscriptions
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- 7) S'assurer que les profils restent lisibles (comptes "disparus" = souvent RLS profiles)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'profiles'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', r.policyname);
  END LOOP;
END $$;

CREATE POLICY "profiles_select" ON public.profiles
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "profiles_insert" ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());

CREATE POLICY "profiles_update" ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid() OR public.is_admin())
  WITH CHECK (id = auth.uid() OR public.is_admin());
