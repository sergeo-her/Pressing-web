-- CLIENTS_BACKFILL.sql
CREATE TABLE IF NOT EXISTS public.pressing_customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pressing_id UUID NOT NULL REFERENCES public.pressings(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (pressing_id, customer_id)
);

ALTER TABLE public.pressing_customers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "pc_select" ON public.pressing_customers;
DROP POLICY IF EXISTS "pc_insert_own" ON public.pressing_customers;
DROP POLICY IF EXISTS "pc_all" ON public.pressing_customers;

CREATE POLICY "pc_select" ON public.pressing_customers
  FOR SELECT TO authenticated
  USING (
    auth.uid() = customer_id
    OR EXISTS (SELECT 1 FROM public.pressings p WHERE p.id = pressing_id AND p.owner_profile_id = auth.uid())
  );

CREATE POLICY "pc_insert_own" ON public.pressing_customers
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = customer_id);

-- Rattrapage depuis les commandes
INSERT INTO public.pressing_customers (pressing_id, customer_id, joined_at)
SELECT DISTINCT o.pressing_id, o.customer_id, MIN(o.created_at)
FROM public.orders o
WHERE o.pressing_id IS NOT NULL AND o.customer_id IS NOT NULL
GROUP BY o.pressing_id, o.customer_id
ON CONFLICT (pressing_id, customer_id) DO NOTHING;
