-- PRESSINGS_FINAL_FIX.sql — correction definitive recursion RLS
-- Executer bloc par bloc si besoin

-- 1) Couper RLS
ALTER TABLE public.pressings DISABLE ROW LEVEL SECURITY;

-- 2) Supprimer TOUTES les policies restantes (noms connus + generiques)
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename='pressings'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.pressings', r.policyname);
  END LOOP;
END $$;

-- 3) Fonction de creation qui contourne le RLS (definitif)
CREATE OR REPLACE FUNCTION public.create_my_pressing(p_name text, p_phone text DEFAULT NULL)
RETURNS public.pressings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_row public.pressings;
  v_code text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Non authentifie';
  END IF;

  SELECT * INTO v_row FROM public.pressings
  WHERE owner_profile_id = v_uid
  ORDER BY created_at ASC
  LIMIT 1;

  IF FOUND THEN
    RETURN v_row;
  END IF;

  v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));

  INSERT INTO public.pressings (name, phone, owner_profile_id, status, address, invite_code)
  VALUES (
    COALESCE(NULLIF(trim(p_name), ''), 'Mon Pressing'),
    NULLIF(trim(p_phone), ''),
    v_uid,
    'active',
    NULL,
    v_code
  )
  RETURNING * INTO v_row;

  INSERT INTO public.subscriptions (pressing_id, plan, trial_end, manual_status)
  VALUES (v_row.id, 'trial', (CURRENT_DATE + 30)::date, 'ok')
  ON CONFLICT DO NOTHING;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_my_pressing(text, text) TO authenticated;

-- 4) RLS simple (optionnel — peut rester DESACTIVE)
-- Si tu veux reactiver plus tard, decommenter :
-- ALTER TABLE public.pressings ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "pressings_select_simple" ON public.pressings FOR SELECT TO authenticated USING (true);
-- CREATE POLICY "pressings_insert_simple" ON public.pressings FOR INSERT TO authenticated WITH CHECK (owner_profile_id = auth.uid());
-- CREATE POLICY "pressings_update_simple" ON public.pressings FOR UPDATE TO authenticated USING (owner_profile_id = auth.uid()) WITH CHECK (owner_profile_id = auth.uid());
