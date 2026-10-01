-- ============================================================
-- Admin : lecture/suppression profils + notifications
-- Supabase → SQL Editor → Run
-- ============================================================

-- Helper admin (si pas déjà créé)
CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
  );
$$;

-- Profiles : admin peut tout lire / supprimer (sauf se protéger côté app)
DROP POLICY IF EXISTS "profiles_admin_all" ON profiles;
CREATE POLICY "profiles_admin_all" ON profiles
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- Notifications : admin peut insérer pour n'importe quel user
DROP POLICY IF EXISTS "notifications_admin_insert" ON notifications;
CREATE POLICY "notifications_admin_insert" ON notifications
  FOR INSERT TO authenticated
  WITH CHECK (is_admin() OR auth.uid() = user_id);

-- Push : admin peut supprimer
DROP POLICY IF EXISTS "push_sub_admin_all" ON push_subscriptions;
CREATE POLICY "push_sub_admin_all" ON push_subscriptions
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

-- Optionnel : supprimer les lignes de test liées (à lancer manuellement si besoin)
-- DELETE FROM notifications WHERE user_id IN (SELECT id FROM profiles WHERE role <> 'admin');
-- DELETE FROM push_subscriptions WHERE user_id IN (SELECT id FROM profiles WHERE role <> 'admin');
