-- PROFILE_FIX.sql (sans $ — collage mobile OK)
-- Supabase SQL Editor → coller TOUT → Run

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS 'SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = ''admin''::user_role)';

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_select_my_customers" ON public.profiles;
DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_select_own_or_admin" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_admin" ON public.profiles;
DROP POLICY IF EXISTS "Profiles are viewable by users who created them" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;

CREATE POLICY "profiles_select_own_or_admin" ON public.profiles
  FOR SELECT TO authenticated
  USING (auth.uid() = id OR public.is_admin());

CREATE POLICY "profiles_select_my_customers" ON public.profiles
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.pressing_customers pc
      JOIN public.pressings p ON p.id = pc.pressing_id
      WHERE pc.customer_id = profiles.id
        AND p.owner_profile_id = auth.uid()
    )
  );

CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id OR public.is_admin());

CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id OR public.is_admin())
  WITH CHECK (auth.uid() = id OR public.is_admin());

-- RPC : crée / lit le profil de l utilisateur connecte (bypass RLS)
CREATE OR REPLACE FUNCTION public.ensure_my_profile(
  p_full_name text DEFAULT NULL,
  p_phone text DEFAULT NULL,
  p_role text DEFAULT 'client'
)
RETURNS SETOF public.profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $body$
DECLARE
  uid uuid := auth.uid();
  v_role user_role;
  v_name text;
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Non authentifie';
  END IF;

  BEGIN
    v_role := COALESCE(NULLIF(p_role, ''), 'client')::user_role;
  EXCEPTION WHEN others THEN
    v_role := 'client'::user_role;
  END;

  v_name := COALESCE(NULLIF(p_full_name, ''), 'Utilisateur');

  INSERT INTO public.profiles (id, full_name, phone, role)
  VALUES (uid, v_name, NULLIF(p_phone, ''), v_role)
  ON CONFLICT (id) DO UPDATE SET
    full_name = COALESCE(NULLIF(EXCLUDED.full_name, ''), profiles.full_name),
    phone = COALESCE(NULLIF(EXCLUDED.phone, ''), profiles.phone);

  RETURN QUERY SELECT * FROM public.profiles WHERE id = uid;
END;
$body$;

GRANT EXECUTE ON FUNCTION public.ensure_my_profile(text, text, text) TO authenticated;

-- Trigger nouveaux comptes Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $body$
DECLARE
  v_role user_role;
BEGIN
  BEGIN
    v_role := COALESCE(NULLIF(NEW.raw_user_meta_data->>'role', ''), 'client')::user_role;
  EXCEPTION WHEN others THEN
    v_role := 'client'::user_role;
  END;

  INSERT INTO public.profiles (id, full_name, phone, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1), 'Utilisateur'),
    NULLIF(NEW.raw_user_meta_data->>'phone', ''),
    v_role
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$body$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Reparer TOUS les comptes Auth sans profil
INSERT INTO public.profiles (id, full_name, phone, role)
SELECT
  u.id,
  COALESCE(u.raw_user_meta_data->>'full_name', split_part(u.email, '@', 1), 'Utilisateur'),
  NULLIF(u.raw_user_meta_data->>'phone', ''),
  CASE
    WHEN (u.raw_user_meta_data->>'role') IN ('client','pressing','agent','admin')
      THEN (u.raw_user_meta_data->>'role')::user_role
    ELSE 'client'::user_role
  END
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = u.id)
ON CONFLICT (id) DO NOTHING;
