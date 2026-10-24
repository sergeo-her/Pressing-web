-- Optionnel : permettre à l'admin d'écrire client_pass_enabled
-- Si RLS bloque, exécute ceci (ou désactive RLS sur platform_settings pour service role déjà utilisé côté client authentifié)

INSERT INTO public.platform_settings (key, value)
VALUES ('client_pass_enabled', '{"enabled": false}'::jsonb)
ON CONFLICT (key) DO NOTHING;
