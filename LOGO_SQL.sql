-- LOGO_SQL.sql — colonne logo pour chaque pressing
ALTER TABLE public.pressings ADD COLUMN IF NOT EXISTS logo_url TEXT;
