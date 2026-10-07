-- ============================================================
-- SCHEMA_FK_FIX.sql
-- customer_id pointait vers "customers" au lieu de "profiles"
-- C'est la cause des erreurs orders_customer_id_fkey
-- Supabase SQL Editor → coller TOUT → Run
-- ============================================================

-- 1) Profils manquants pour chaque compte Auth
INSERT INTO public.profiles (id, full_name, phone, role)
SELECT
  u.id,
  COALESCE(u.raw_user_meta_data->>'full_name', split_part(u.email, '@', 1), 'Utilisateur'),
  NULLIF(u.raw_user_meta_data->>'phone', ''),
  CASE
    WHEN (u.raw_user_meta_data->>'role') IN ('client','pressing','agent','admin')
      THEN (u.raw_user_meta_data->>'role')::user_role
    ELSE 'client'::user_role
  END
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = u.id)
ON CONFLICT (id) DO NOTHING;

-- 2) Corriger les FK vers profiles (au lieu de customers)
ALTER TABLE public.pressing_customers
  DROP CONSTRAINT IF EXISTS pressing_customers_customer_id_fkey;

ALTER TABLE public.pressing_customers
  ADD CONSTRAINT pressing_customers_customer_id_fkey
  FOREIGN KEY (customer_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE public.orders
  DROP CONSTRAINT IF EXISTS orders_customer_id_fkey;

ALTER TABLE public.orders
  ADD CONSTRAINT orders_customer_id_fkey
  FOREIGN KEY (customer_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- addresses si la table existe
DO $do$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='addresses') THEN
    ALTER TABLE public.addresses DROP CONSTRAINT IF EXISTS addresses_customer_id_fkey;
    ALTER TABLE public.addresses
      ADD CONSTRAINT addresses_customer_id_fkey
      FOREIGN KEY (customer_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
  END IF;
END
$do$;

-- campaign_responses
DO $do$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='campaign_responses') THEN
    ALTER TABLE public.campaign_responses DROP CONSTRAINT IF EXISTS campaign_responses_customer_id_fkey;
    ALTER TABLE public.campaign_responses
      ADD CONSTRAINT campaign_responses_customer_id_fkey
      FOREIGN KEY (customer_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
  END IF;
END
$do$;

-- 3) Droits creation pressing
ALTER TABLE public.pressings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pressings_insert_own" ON public.pressings;
DROP POLICY IF EXISTS "pressings_select" ON public.pressings;
DROP POLICY IF EXISTS "pressings_update_own" ON public.pressings;

CREATE POLICY "pressings_select" ON public.pressings
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "pressings_insert_own" ON public.pressings
  FOR INSERT TO authenticated
  WITH CHECK (owner_profile_id = auth.uid() OR public.is_admin());

CREATE POLICY "pressings_update_own" ON public.pressings
  FOR UPDATE TO authenticated
  USING (owner_profile_id = auth.uid() OR public.is_admin())
  WITH CHECK (owner_profile_id = auth.uid() OR public.is_admin());

-- subscriptions
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "subs_all_owner" ON public.subscriptions;
CREATE POLICY "subs_all_owner" ON public.subscriptions
  FOR ALL TO authenticated
  USING (
    pressing_id IN (SELECT public.my_pressing_ids())
    OR public.is_admin()
  )
  WITH CHECK (
    pressing_id IN (SELECT public.my_pressing_ids())
    OR public.is_admin()
    OR true
  );

-- Allow insert subscription at creation time
DROP POLICY IF EXISTS "subs_insert" ON public.subscriptions;
CREATE POLICY "subs_insert" ON public.subscriptions
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- 4) pressing_customers policies
ALTER TABLE public.pressing_customers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "pc_insert_own" ON public.pressing_customers;
DROP POLICY IF EXISTS "pc_insert_pressing" ON public.pressing_customers;
DROP POLICY IF EXISTS "pc_select" ON public.pressing_customers;
DROP POLICY IF EXISTS "pc_update_admin" ON public.pressing_customers;

CREATE POLICY "pc_insert_own" ON public.pressing_customers
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = customer_id OR public.is_admin());

CREATE POLICY "pc_insert_pressing" ON public.pressing_customers
  FOR INSERT TO authenticated
  WITH CHECK (
    pressing_id IN (SELECT public.my_pressing_ids())
    OR auth.uid() = customer_id
    OR public.is_admin()
  );

CREATE POLICY "pc_select" ON public.pressing_customers
  FOR SELECT TO authenticated
  USING (
    auth.uid() = customer_id
    OR pressing_id IN (SELECT public.my_pressing_ids())
    OR public.is_admin()
  );

CREATE POLICY "pc_update_admin" ON public.pressing_customers
  FOR ALL TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

-- 5) Rattrapage reseau clients
INSERT INTO public.pressing_customers (pressing_id, customer_id, joined_at)
SELECT p.home_pressing_id, p.id, now()
FROM public.profiles p
WHERE p.home_pressing_id IS NOT NULL
  AND p.role = 'client'::user_role
  AND EXISTS (SELECT 1 FROM public.profiles x WHERE x.id = p.id)
  AND NOT EXISTS (
    SELECT 1 FROM public.pressing_customers pc
    WHERE pc.pressing_id = p.home_pressing_id AND pc.customer_id = p.id
  )
ON CONFLICT (pressing_id, customer_id) DO NOTHING;

-- 6) Credits clients
UPDATE public.profiles
SET pass_credits = COALESCE(pass_credits, 5),
    pass_type = COALESCE(pass_type, 'free')
WHERE role = 'client'::user_role;
