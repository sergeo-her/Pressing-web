-- ============================================================
-- FIX COMPLET RLS + Pass + Commandes pressing
-- À exécuter EN ENTIER dans Supabase → SQL Editor → Run
-- ============================================================

-- ---------- Helpers (évite la récursion RLS sur profiles) ----------
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
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

GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_pressing_ids() TO authenticated;

-- ---------- Colonnes Pass ----------
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS pass_credits INT DEFAULT 5,
  ADD COLUMN IF NOT EXISTS pass_type VARCHAR(32) DEFAULT 'free',
  ADD COLUMN IF NOT EXISTS pass_expiration TIMESTAMPTZ NULL;

-- ---------- Table demandes Pass ----------
CREATE TABLE IF NOT EXISTS pass_recharge_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  pack_id VARCHAR(64) NOT NULL,
  amount INT NOT NULL,
  credits INT NULL,
  days INT NULL,
  note TEXT NULL,
  status VARCHAR(24) NOT NULL DEFAULT 'pending',
  user_name TEXT,
  user_phone TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  processed_at TIMESTAMPTZ NULL
);
CREATE INDEX IF NOT EXISTS idx_pass_req_status ON pass_recharge_requests(status);
ALTER TABLE pass_recharge_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "clients insert own pass requests" ON pass_recharge_requests;
DROP POLICY IF EXISTS "clients read own pass requests" ON pass_recharge_requests;
DROP POLICY IF EXISTS "admin all pass requests" ON pass_recharge_requests;

CREATE POLICY "pass_req_insert_own" ON pass_recharge_requests
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);

CREATE POLICY "pass_req_select" ON pass_recharge_requests
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "pass_req_update_admin" ON pass_recharge_requests
  FOR UPDATE TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

-- ---------- platform_settings ----------
CREATE TABLE IF NOT EXISTS platform_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT UNIQUE NOT NULL,
  value JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT now()
);
ALTER TABLE platform_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "authenticated read platform_settings" ON platform_settings;
DROP POLICY IF EXISTS "admin write platform_settings" ON platform_settings;

CREATE POLICY "settings_read" ON platform_settings
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "settings_write_admin" ON platform_settings
  FOR ALL TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

INSERT INTO platform_settings (key, value)
VALUES ('pass_prices', '{
  "packs": {
    "pack_5":  {"price":500,  "credits":5,  "days":null, "label":"Pass 5 réservations",  "desc":"Essai ou besoins ponctuels."},
    "pack_10": {"price":1000, "credits":10, "days":null, "label":"Pass 10 réservations", "desc":"Idéal pour un usage régulier."},
    "unlimited":{"price":5000,"credits":null,"days":365,  "label":"Pass Illimité 1 an",   "desc":"Réservations illimitées pendant 365 jours."}
  }
}'::jsonb)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();

-- ---------- PROFILES : lecture admin + soi-même ----------
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "clients update own pass fields" ON profiles;
DROP POLICY IF EXISTS "admin update profiles" ON profiles;
DROP POLICY IF EXISTS "profiles_select_own" ON profiles;
DROP POLICY IF EXISTS "profiles_select_admin" ON profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
DROP POLICY IF EXISTS "profiles_update_admin" ON profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;

CREATE POLICY "profiles_select_own_or_admin" ON profiles
  FOR SELECT TO authenticated
  USING (auth.uid() = id OR public.is_admin());

-- Pressing / agent peuvent lire le profil des clients liés aux commandes (via admin-like broad read for authenticated limited?)
-- Pour simplifier la jointure client sur les commandes :
CREATE POLICY "profiles_select_authenticated_basic" ON profiles
  FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_update_admin" ON profiles
  FOR UPDATE TO authenticated
  USING (public.is_admin()) WITH CHECK (public.is_admin());

-- ---------- ORDERS : client + pressing propriétaire + admin ----------
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "orders_select" ON orders;
DROP POLICY IF EXISTS "orders_insert_client" ON orders;
DROP POLICY IF EXISTS "orders_update" ON orders;

CREATE POLICY "orders_select" ON orders
  FOR SELECT TO authenticated
  USING (
    customer_id = auth.uid()
    OR pressing_id IN (SELECT public.my_pressing_ids())
    OR public.is_admin()
  );

CREATE POLICY "orders_insert_client" ON orders
  FOR INSERT TO authenticated
  WITH CHECK (customer_id = auth.uid() OR public.is_admin());

CREATE POLICY "orders_update" ON orders
  FOR UPDATE TO authenticated
  USING (
    customer_id = auth.uid()
    OR pressing_id IN (SELECT public.my_pressing_ids())
    OR public.is_admin()
  );

-- order_items
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "order_items_all" ON order_items;
CREATE POLICY "order_items_select" ON order_items FOR SELECT TO authenticated USING (true);
CREATE POLICY "order_items_insert" ON order_items FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "order_items_update" ON order_items FOR UPDATE TO authenticated USING (true);

-- ---------- NOTIFICATIONS ----------
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users insert notifications" ON notifications;
DROP POLICY IF EXISTS "users read own notifications" ON notifications;
DROP POLICY IF EXISTS "users update own notifications" ON notifications;

CREATE POLICY "notif_insert" ON notifications
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "notif_select_own" ON notifications
  FOR SELECT TO authenticated USING (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "notif_update_own" ON notifications
  FOR UPDATE TO authenticated USING (auth.uid() = user_id OR public.is_admin());

-- ---------- RPC admin : lister clients + demandes Pass ----------
CREATE OR REPLACE FUNCTION public.admin_list_clients()
RETURNS TABLE (id uuid, full_name text, phone text, role text, pass_credits int, pass_type text, pass_expiration timestamptz)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.id, p.full_name, p.phone, p.role, p.pass_credits, p.pass_type, p.pass_expiration
  FROM profiles p
  WHERE p.role = 'client'
    AND public.is_admin()
  ORDER BY p.full_name NULLS LAST;
$$;

CREATE OR REPLACE FUNCTION public.admin_list_pass_requests()
RETURNS SETOF pass_recharge_requests
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT r.* FROM pass_recharge_requests r
  WHERE public.is_admin()
  ORDER BY r.created_at DESC
  LIMIT 100;
$$;

GRANT EXECUTE ON FUNCTION public.admin_list_clients() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_list_pass_requests() TO authenticated;

-- ---------- Init crédits clients existants ----------
UPDATE profiles
SET pass_credits = COALESCE(pass_credits, 5), pass_type = COALESCE(pass_type, 'free')
WHERE role = 'client';
