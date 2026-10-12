-- AGENT_ORDERS_SQL.sql — l'agent peut avancer le statut des commandes de son pressing
-- Sans $$ pour copier-coller mobile

DROP POLICY IF EXISTS "orders_update_agent" ON public.orders;
DROP POLICY IF EXISTS "orders_select_agent" ON public.orders;

CREATE POLICY "orders_select_agent" ON public.orders
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.agents a
      WHERE a.id = auth.uid() AND a.pressing_id = orders.pressing_id AND a.status = 'active'
    )
    OR EXISTS (
      SELECT 1 FROM public.pressings p
      WHERE p.id = orders.pressing_id AND p.owner_profile_id = auth.uid()
    )
    OR customer_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles pr WHERE pr.id = auth.uid() AND pr.role::text = 'admin')
  );

CREATE POLICY "orders_update_agent" ON public.orders
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.agents a
      WHERE a.id = auth.uid() AND a.pressing_id = orders.pressing_id AND a.status = 'active'
    )
    OR EXISTS (
      SELECT 1 FROM public.pressings p
      WHERE p.id = orders.pressing_id AND p.owner_profile_id = auth.uid()
    )
    OR EXISTS (SELECT 1 FROM public.profiles pr WHERE pr.id = auth.uid() AND pr.role::text = 'admin')
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.agents a
      WHERE a.id = auth.uid() AND a.pressing_id = orders.pressing_id AND a.status = 'active'
    )
    OR EXISTS (
      SELECT 1 FROM public.pressings p
      WHERE p.id = orders.pressing_id AND p.owner_profile_id = auth.uid()
    )
    OR EXISTS (SELECT 1 FROM public.profiles pr WHERE pr.id = auth.uid() AND pr.role::text = 'admin')
  );
