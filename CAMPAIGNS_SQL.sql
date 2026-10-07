-- CAMPAIGNS_SQL.sql — droits publication campagnes
-- Supabase SQL Editor → Run

CREATE TABLE IF NOT EXISTS public.campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pressing_id UUID NOT NULL REFERENCES public.pressings(id) ON DELETE CASCADE,
  created_by UUID REFERENCES public.profiles(id),
  title TEXT NOT NULL,
  message TEXT,
  campaign_date DATE NOT NULL,
  mode TEXT DEFAULT 'domicile',
  status TEXT DEFAULT 'published',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.campaign_slots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
  zone_label TEXT NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL
);

CREATE TABLE IF NOT EXISTS public.campaign_responses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID NOT NULL REFERENCES public.campaigns(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaign_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.campaign_responses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "camp_select" ON public.campaigns;
DROP POLICY IF EXISTS "camp_insert" ON public.campaigns;
DROP POLICY IF EXISTS "camp_update" ON public.campaigns;
DROP POLICY IF EXISTS "cslot_select" ON public.campaign_slots;
DROP POLICY IF EXISTS "cslot_insert" ON public.campaign_slots;
DROP POLICY IF EXISTS "cresp_select" ON public.campaign_responses;
DROP POLICY IF EXISTS "cresp_insert" ON public.campaign_responses;

CREATE POLICY "camp_select" ON public.campaigns
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "camp_insert" ON public.campaigns
  FOR INSERT TO authenticated
  WITH CHECK (
    pressing_id IN (SELECT public.my_pressing_ids())
    OR public.is_admin()
  );

CREATE POLICY "camp_update" ON public.campaigns
  FOR UPDATE TO authenticated
  USING (
    pressing_id IN (SELECT public.my_pressing_ids())
    OR public.is_admin()
  );

CREATE POLICY "cslot_select" ON public.campaign_slots
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "cslot_insert" ON public.campaign_slots
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "cresp_select" ON public.campaign_responses
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "cresp_insert" ON public.campaign_responses
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = customer_id OR public.is_admin());
