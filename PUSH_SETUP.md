# Notifications push natives — Pressing Connecté

## 1. SQL (obligatoire)
Exécuter `PUSH_SQL_MIGRATION.sql` dans Supabase → SQL Editor.

## 2. Clés VAPID
La clé **publique** est déjà dans `index.html` (`VAPID_PUBLIC_KEY`).

Générer une paire si besoin :
```bash
npx web-push generate-vapid-keys
```
Mettre la **privée** en secret Supabase :
```bash
supabase secrets set VAPID_PUBLIC_KEY="BCpk..." VAPID_PRIVATE_KEY="...." VAPID_SUBJECT="mailto:vous@email.com"
```

## 3. Edge Function `send-push`
Code dans `supabase-edge-send-push/index.ts`.

```bash
supabase functions deploy send-push
```

Sans cette fonction, l’app enregistre quand même les abonnements et affiche les notifications **quand l’onglet est ouvert** (Notification API + polling). Les push **écran verrouillé / app fermée** nécessitent l’Edge Function.

## 4. Côté utilisateur
1. Ouvrir le site (idéalement en PWA installée).
2. Accepter le bandeau **Activer les notifications**.
3. Sur iPhone : installer sur l’écran d’accueil (Safari) puis activer les notifs.

## Événements qui déclenchent une push
- Nouvelle commande → propriétaire du pressing
- Demande de recharge Pass → admins
- Avancement statut commande / collecte programmée → client
