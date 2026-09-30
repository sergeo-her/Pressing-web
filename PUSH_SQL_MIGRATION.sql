-- ============================================================
-- Push subscriptions — créer / aligner la table
-- Supabase → SQL Editor → Run
-- ============================================================

CREATE TABLE IF NOT EXISTS push_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  endpoint TEXT NOT NULL,
  p256dh TEXT NOT NULL,
  auth TEXT NOT NULL,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Si la table existait déjà sans ces colonnes :
ALTER TABLE push_subscriptions ADD COLUMN IF NOT EXISTS user_agent TEXT;
ALTER TABLE push_subscriptions ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE push_subscriptions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

CREATE UNIQUE INDEX IF NOT EXISTS push_subscriptions_endpoint_uidx ON push_subscriptions(endpoint);
CREATE INDEX IF NOT EXISTS idx_push_sub_user ON push_subscriptions(user_id);

ALTER TABLE push_subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "push_sub_own" ON push_subscriptions;
DROP POLICY IF EXISTS "push_sub_admin_read" ON push_subscriptions;
DROP POLICY IF EXISTS "push_sub_insert_own" ON push_subscriptions;
DROP POLICY IF EXISTS "push_sub_select_own" ON push_subscriptions;
DROP POLICY IF EXISTS "push_sub_update_own" ON push_subscriptions;
DROP POLICY IF EXISTS "push_sub_delete_own" ON push_subscriptions;

CREATE POLICY "push_sub_select_own" ON push_subscriptions
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "push_sub_insert_own" ON push_subscriptions
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "push_sub_update_own" ON push_subscriptions
  FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "push_sub_delete_own" ON push_subscriptions
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- Rafraîchir le cache schéma API (si besoin)
NOTIFY pgrst, 'reload schema';
