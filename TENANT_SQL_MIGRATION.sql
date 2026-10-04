-- ============================================================
-- Multi-tenant étanche / marque blanche légère
-- Supabase → SQL Editor → Run
-- ============================================================

-- 1) Code invitation unique par pressing
ALTER TABLE pressings ADD COLUMN IF NOT EXISTS invite_code TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS pressings_invite_code_uidx
  ON pressings (invite_code) WHERE invite_code IS NOT NULL;

-- Générer un code pour les pressings existants sans code
UPDATE pressings
SET invite_code = upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6))
WHERE invite_code IS NULL;

-- 2) Pressing "maison" du client
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS home_pressing_id UUID REFERENCES pressings(id);

-- 3) Helper admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin');
$$;

-- 4) Résoudre un code (lecture publique limitée — pas de fuite de la liste)
CREATE OR REPLACE FUNCTION resolve_pressing_code(p_code text)
RETURNS TABLE(id uuid, name text, invite_code text, address text, phone text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT pr.id, pr.name, pr.invite_code, pr.address, pr.phone
  FROM pressings pr
  WHERE pr.status = 'active'
    AND upper(pr.invite_code) = upper(trim(p_code))
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION resolve_pressing_code(text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION get_pressing_public(p_id uuid)
RETURNS TABLE(id uuid, name text, invite_code text, address text, phone text, whatsapp text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT pr.id, pr.name, pr.invite_code, pr.address, pr.phone, pr.whatsapp
  FROM pressings pr
  WHERE pr.id = p_id AND pr.status = 'active'
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION get_pressing_public(uuid) TO authenticated;

-- 5) RLS : les clients ne listent plus tous les pressings
ALTER TABLE pressings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pressings_select_active_all" ON pressings;
DROP POLICY IF EXISTS "pressings_public_read" ON pressings;
DROP POLICY IF EXISTS "pressings_select_tenant" ON pressings;

-- Lecture pressing :
-- - admin : tout
-- - propriétaire / agent du pressing
-- - client rattaché (home_pressing_id ou pressing_customers)
CREATE POLICY "pressings_select_tenant" ON pressings
  FOR SELECT TO authenticated
  USING (
    is_admin()
    OR owner_profile_id = auth.uid()
    OR id IN (SELECT pressing_id FROM agents WHERE id = auth.uid())
    OR id IN (SELECT home_pressing_id FROM profiles WHERE id = auth.uid() AND home_pressing_id IS NOT NULL)
    OR id IN (SELECT pressing_id FROM pressing_customers WHERE customer_id = auth.uid())
  );

-- Les propriétaires peuvent mettre à jour leur fiche (invite_code inclus)
DROP POLICY IF EXISTS "pressings_update_owner" ON pressings;
CREATE POLICY "pressings_update_owner" ON pressings
  FOR UPDATE TO authenticated
  USING (is_admin() OR owner_profile_id = auth.uid())
  WITH CHECK (is_admin() OR owner_profile_id = auth.uid());

-- 6) Profiles : client peut mettre à jour son home_pressing_id
DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id OR is_admin())
  WITH CHECK (auth.uid() = id OR is_admin());
