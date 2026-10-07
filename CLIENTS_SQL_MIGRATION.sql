-- ============================================================
-- Clients liés au pressing + adresses domicile / travail
-- Supabase → SQL Editor → Run (relançable sans erreur)
-- ============================================================

-- Helpers
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'::user_role
  );
$$;

CREATE OR REPLACE FUNCTION public.my_pressing_ids()
RETURNS SETOF uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT id FROM public.pressings WHERE owner_profile_id = auth.uid();
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_pressing_ids() TO authenticated;

-- Colonnes adresse
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS home_address TEXT,
  ADD COLUMN IF NOT EXISTS work_address TEXT;

-- Table liaison client ↔ pressing
CREATE TABLE IF NOT EXISTS pressing_customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pressing_id UUID NOT NULL REFERENCES pressings(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (pressing_id, customer_id)
);
CREATE INDEX IF NOT EXISTS idx_pressing_customers_pressing ON pressing_customers(pressing_id);
CREATE INDEX IF NOT EXISTS idx_pressing_customers_customer ON pressing_customers(customer_id);

ALTER TABLE pressing_customers ENABLE ROW LEVEL SECURITY;

-- Drop TOUTES les policies connues avant recréation
DROP POLICY IF EXISTS "pc_insert_own" ON pressing_customers;
DROP POLICY IF EXISTS "pc_select" ON pressing_customers;
DROP POLICY IF EXISTS "pc_admin" ON pressing_customers;
DROP POLICY IF EXISTS "pc_update_admin" ON pressing_customers;
DROP POLICY IF EXISTS "pc_delete_admin" ON pressing_customers;
DROP POLICY IF EXISTS "pc_all_admin" ON pressing_customers;

CREATE POLICY "pc_insert_own" ON pressing_customers
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = customer_id OR public.is_admin());

CREATE POLICY "pc_select" ON pressing_customers
  FOR SELECT TO authenticated
  USING (
    auth.uid() = customer_id
    OR pressing_id IN (SELECT public.my_pressing_ids())
    OR public.is_admin()
  );

CREATE POLICY "pc_update_admin" ON pressing_customers
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Rattrapage clients déjà présents via commandes
INSERT INTO pressing_customers (pressing_id, customer_id, joined_at)
SELECT DISTINCT o.pressing_id, o.customer_id, MIN(o.created_at)
FROM orders o
WHERE o.pressing_id IS NOT NULL AND o.customer_id IS NOT NULL
GROUP BY o.pressing_id, o.customer_id
ON CONFLICT (pressing_id, customer_id) DO NOTHING;
