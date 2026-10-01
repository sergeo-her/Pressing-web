-- ============================================================
-- Nettoyage : droits de suppression (notifs / commandes)
-- Supabase → SQL Editor → Run
-- ============================================================

CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin');
$$;

-- Notifications : chacun peut supprimer les siennes ; admin tout
DROP POLICY IF EXISTS "notifications_delete_own" ON notifications;
CREATE POLICY "notifications_delete_own" ON notifications
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id OR is_admin());

-- Orders : client supprime ses commandes clôturées ; pressing propriétaire ; admin tout
-- (Adapte si des policies DELETE existent déjà)
DROP POLICY IF EXISTS "orders_delete_client_closed" ON orders;
CREATE POLICY "orders_delete_client_closed" ON orders
  FOR DELETE TO authenticated
  USING (
    is_admin()
    OR (customer_id = auth.uid() AND order_status IN ('livre','termine'))
    OR (
      order_status IN ('livre','termine')
      AND pressing_id IN (SELECT id FROM pressings WHERE owner_profile_id = auth.uid())
    )
  );

-- Pass requests : admin peut purger
DROP POLICY IF EXISTS "pass_req_admin_delete" ON pass_recharge_requests;
CREATE POLICY "pass_req_admin_delete" ON pass_recharge_requests
  FOR DELETE TO authenticated
  USING (is_admin());
