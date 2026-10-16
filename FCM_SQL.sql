-- FCM tokens
CREATE TABLE IF NOT EXISTS public.fcm_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, token)
);
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user ON public.fcm_tokens(user_id);

ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "fcm_select_own" ON public.fcm_tokens;
DROP POLICY IF EXISTS "fcm_insert_own" ON public.fcm_tokens;
DROP POLICY IF EXISTS "fcm_update_own" ON public.fcm_tokens;
DROP POLICY IF EXISTS "fcm_delete_own" ON public.fcm_tokens;

CREATE POLICY "fcm_select_own" ON public.fcm_tokens FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
CREATE POLICY "fcm_insert_own" ON public.fcm_tokens FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "fcm_update_own" ON public.fcm_tokens FOR UPDATE TO authenticated
  USING (auth.uid() = user_id);
CREATE POLICY "fcm_delete_own" ON public.fcm_tokens FOR DELETE TO authenticated
  USING (auth.uid() = user_id);
