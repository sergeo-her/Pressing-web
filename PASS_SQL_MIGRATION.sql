-- ============================================================
-- Pass Rechargement — migration SQL à exécuter dans Supabase
-- SQL Editor → New query → Run
-- ============================================================

-- 1) Colonnes sur profiles
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS pass_credits INT DEFAULT 5,
  ADD COLUMN IF NOT EXISTS pass_type VARCHAR(32) DEFAULT 'free',
  ADD COLUMN IF NOT EXISTS pass_expiration TIMESTAMPTZ NULL;

-- 2) Table des demandes de recharge
CREATE TABLE IF NOT EXISTS pass_recharge_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  pack_id VARCHAR(64) NOT NULL,
  amount INT NOT NULL,
  credits INT NULL,
  days INT NULL,
  note TEXT NULL,
  status VARCHAR(24) NOT NULL DEFAULT 'pending',
  user_name TEXT,
  user_phone TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  processed_at TIMESTAMPTZ NULL
);

CREATE INDEX IF NOT EXISTS idx_pass_req_status ON pass_recharge_requests(status);
CREATE INDEX IF NOT EXISTS idx_pass_req_user ON pass_recharge_requests(user_id);

ALTER TABLE pass_recharge_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "clients insert own pass requests" ON pass_recharge_requests;
CREATE POLICY "clients insert own pass requests"
  ON pass_recharge_requests FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "clients read own pass requests" ON pass_recharge_requests;
CREATE POLICY "clients read own pass requests"
  ON pass_recharge_requests FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "admin all pass requests" ON pass_recharge_requests;
CREATE POLICY "admin all pass requests"
  ON pass_recharge_requests FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

-- 3) Clients peuvent mettre à jour leurs propres crédits
DROP POLICY IF EXISTS "clients update own pass fields" ON profiles;
CREATE POLICY "clients update own pass fields"
  ON profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "admin update profiles" ON profiles;
CREATE POLICY "admin update profiles"
  ON profiles FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

-- 4) Tarifs flexibles (admin)
CREATE TABLE IF NOT EXISTS platform_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT UNIQUE NOT NULL,
  value JSONB NOT NULL DEFAULT '{}'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE platform_settings ENABLE ROW LEVEL SECURITY;

-- Lecture publique authentifiée (clients voient les tarifs)
DROP POLICY IF EXISTS "authenticated read platform_settings" ON platform_settings;
CREATE POLICY "authenticated read platform_settings"
  ON platform_settings FOR SELECT
  TO authenticated
  USING (true);

-- Seul l'admin peut écrire
DROP POLICY IF EXISTS "admin write platform_settings" ON platform_settings;
CREATE POLICY "admin write platform_settings"
  ON platform_settings FOR ALL
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  );

-- Valeurs initiales (250 / 500)
INSERT INTO platform_settings (key, value)
VALUES ('pass_prices', '{"pack_10_price":250,"unlimited_30_price":500}'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- 5) Initialiser les clients existants sans pass
UPDATE profiles
SET pass_credits = 5, pass_type = 'free'
WHERE role = 'client' AND pass_credits IS NULL;
