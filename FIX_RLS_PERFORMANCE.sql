-- ============================================================
-- Fix récursion RLS + perf (stack depth / timeouts)
-- Supabase → SQL Editor → Run
-- ============================================================

CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin');
$$;

-- Clients d'un pressing (sans récursion RLS)
CREATE OR REPLACE FUNCTION get_pressing_clients(p_pressing_id uuid)
RETURNS TABLE(
  customer_id uuid,
  joined_at timestamptz,
  full_name text,
  phone text,
  home_address text,
  work_address text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    pc.customer_id,
    pc.joined_at,
    pr.full_name,
    pr.phone,
    pr.home_address,
    pr.work_address
  FROM pressing_customers pc
  JOIN profiles pr ON pr.id = pc.customer_id
  WHERE pc.pressing_id = p_pressing_id
    AND (
      is_admin()
      OR EXISTS (
        SELECT 1 FROM pressings p
        WHERE p.id = p_pressing_id AND p.owner_profile_id = auth.uid()
      )
    )
  ORDER BY pc.joined_at DESC
  LIMIT 200;
$$;

GRANT EXECUTE ON FUNCTION get_pressing_clients(uuid) TO authenticated;

-- Policies profiles simplifiées (évite boucles)
DROP POLICY IF EXISTS "profiles_select_complex" ON profiles;
DROP POLICY IF EXISTS "profiles_select_own_or_related" ON profiles;

-- Lecture : soi-même, ou admin
-- (les détails clients passent par get_pressing_clients)
DROP POLICY IF EXISTS "profiles_select_own" ON profiles;
CREATE POLICY "profiles_select_own" ON profiles
  FOR SELECT TO authenticated
  USING (auth.uid() = id OR is_admin());

-- Pressing owner peut lire profils de SES clients via policy légère
DROP POLICY IF EXISTS "profiles_select_my_customers" ON profiles;
CREATE POLICY "profiles_select_my_customers" ON profiles
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM pressing_customers pc
      JOIN pressings p ON p.id = pc.pressing_id
      WHERE pc.customer_id = profiles.id
        AND p.owner_profile_id = auth.uid()
    )
  );

-- Index utiles pour la perf
CREATE INDEX IF NOT EXISTS idx_pressing_customers_pressing ON pressing_customers(pressing_id);
CREATE INDEX IF NOT EXISTS idx_pressing_customers_customer ON pressing_customers(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_pressing ON orders(pressing_id);
CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_campaigns_pressing ON campaigns(pressing_id);
CREATE INDEX IF NOT EXISTS idx_time_slots_pressing ON time_slots(pressing_id);
CREATE INDEX IF NOT EXISTS idx_services_pressing ON services(pressing_id);
CREATE INDEX IF NOT EXISTS idx_agents_pressing ON agents(pressing_id);
