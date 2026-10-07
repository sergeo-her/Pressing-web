-- ORDERS_CLIENT_FIX.sql
-- Fix FK commandes + clients visibles cote pressing
-- Supabase SQL Editor → Run

-- 1) Profils manquants (tous les comptes Auth)
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

-- 2) Credits bienvenue clients sans pass
UPDATE public.profiles
SET pass_credits = COALESCE(pass_credits, 5),
    pass_type = COALESCE(pass_type, 'free')
WHERE role = 'client'::user_role
  AND (pass_credits IS NULL OR pass_type IS NULL);

-- 3) Policies pressing_customers (client s'inscrit + pressing lit)
ALTER TABLE public.pressing_customers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pc_insert_own" ON public.pressing_customers;
DROP POLICY IF EXISTS "pc_select" ON public.pressing_customers;
DROP POLICY IF EXISTS "pc_update_admin" ON public.pressing_customers;

CREATE POLICY "pc_insert_own" ON public.pressing_customers
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = customer_id OR public.is_admin());

CREATE POLICY "pc_select" ON public.pressing_customers
  FOR SELECT TO authenticated
  USING (
    auth.uid() = customer_id
    OR pressing_id IN (SELECT public.my_pressing_ids())
    OR public.is_admin()
  );

CREATE POLICY "pc_update_admin" ON public.pressing_customers
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- Pressing peut aussi inserer un client dans son reseau
DROP POLICY IF EXISTS "pc_insert_pressing" ON public.pressing_customers;
CREATE POLICY "pc_insert_pressing" ON public.pressing_customers
  FOR INSERT TO authenticated
  WITH CHECK (
    pressing_id IN (SELECT public.my_pressing_ids())
    OR auth.uid() = customer_id
    OR public.is_admin()
  );

-- 4) Rattrapage : clients avec home_pressing_id mais pas dans pressing_customers
INSERT INTO public.pressing_customers (pressing_id, customer_id, joined_at)
SELECT p.home_pressing_id, p.id, now()
FROM public.profiles p
WHERE p.home_pressing_id IS NOT NULL
  AND p.role = 'client'::user_role
  AND NOT EXISTS (
    SELECT 1 FROM public.pressing_customers pc
    WHERE pc.pressing_id = p.home_pressing_id AND pc.customer_id = p.id
  )
ON CONFLICT (pressing_id, customer_id) DO NOTHING;
