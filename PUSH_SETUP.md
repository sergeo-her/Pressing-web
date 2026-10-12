# Notifications push — Pressing Connecté

## Pourquoi Web Push (pas Firebase) ?
- Déjà intégré (VAPID + Service Worker + Edge Function)
- Fonctionne hors navigateur sur Android (Chrome) et PWA installée
- iPhone : uniquement si l'app est installée sur l'écran d'accueil (Safari)

## 1. SQL
Exécuter PUSH_SQL_MIGRATION.sql dans Supabase SQL Editor.

## 2. Secrets VAPID (une fois)
La clé publique est dans index.html (VAPID_PUBLIC_KEY).

Sur un PC ou Termux avec Node :
```
npx web-push generate-vapid-keys
```

Dans Supabase → Project Settings → Edge Functions → Secrets :
- VAPID_PUBLIC_KEY = (clé publique)
- VAPID_PRIVATE_KEY = (clé privée)
- VAPID_SUBJECT = mailto:sergesmoudio14@gmail.com

La clé publique dans index.html doit correspondre à VAPID_PUBLIC_KEY.

## 3. Déployer l'Edge Function
```
supabase functions deploy send-push
```
Ou via le dashboard Supabase : Edge Functions → create/deploy `send-push` avec le code de supabase-edge-send-push/index.ts

Sans cette fonction déployée + secrets, les notifs marchent seulement quand l'onglet est ouvert (Notification API locale).

## 4. Côté utilisateur
1. Ouvrir le site (idéalement installé en PWA)
2. Accepter le bandeau "Activer les notifications"
3. Android : autoriser dans les réglages système si demandé
4. iPhone : Partager → Sur l'écran d'accueil, puis activer les notifs
