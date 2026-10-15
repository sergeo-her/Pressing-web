-- Version mobile : un bloc a la fois

-- BLOC 1
ALTER TABLE public.pressings DISABLE ROW LEVEL SECURITY;

-- BLOC 2 (copie les noms un par un si erreur)
DROP POLICY IF EXISTS "p_delete" ON public.pressings;
DROP POLICY IF EXISTS "p_select" ON public.pressings;
DROP POLICY IF EXISTS "p_insert" ON public.pressings;
DROP POLICY IF EXISTS "p_update" ON public.pressings;
DROP POLICY IF EXISTS "pressings_select" ON public.pressings;
DROP POLICY IF EXISTS "pressings_select_simple" ON public.pressings;
DROP POLICY IF EXISTS "pressings_select_tenant" ON public.pressings;
DROP POLICY IF EXISTS "pressings_insert_simple" ON public.pressings;
DROP POLICY IF EXISTS "pressings_insert_own" ON public.pressings;
DROP POLICY IF EXISTS "pressings_update_simple" ON public.pressings;
DROP POLICY IF EXISTS "pressings_update_own" ON public.pressings;
DROP POLICY IF EXISTS "pressings_update_owner" ON public.pressings;

-- BLOC 3 — fonction de creation (contourne RLS)
CREATE OR REPLACE FUNCTION public.create_my_pressing(p_name text, p_phone text DEFAULT NULL)
RETURNS public.pressings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
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
  ORDER BY created_at ASC LIMIT 1;
  IF FOUND THEN RETURN v_row; END IF;
  v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
  INSERT INTO public.pressings (name, phone, owner_profile_id, status, address, invite_code)
  VALUES (COALESCE(NULLIF(trim(p_name), ''), 'Mon Pressing'), NULLIF(trim(p_phone), ''), v_uid, 'active', NULL, v_code)
  RETURNING * INTO v_row;
  BEGIN
    INSERT INTO public.subscriptions (pressing_id, plan, trial_end, manual_status)
    VALUES (v_row.id, 'trial', (CURRENT_DATE + 30)::date, 'ok');
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  RETURN v_row;
END;
$fn$;

-- BLOC 4
GRANT EXECUTE ON FUNCTION public.create_my_pressing(text, text) TO authenticated;
