// Service worker — installabilité PWA + réception des notifications
// push réelles envoyées par la fonction Supabase Edge "send-push".

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  // Laisse passer toutes les requêtes normalement (pas de cache pour l'instant).
});

// Réception d'une notification push envoyée par le serveur (Web Push + VAPID)
self.addEventListener('push', (event) => {
  let data = { title: 'Pressing Connecté', body: 'Nouvelle notification', url: '/' };
  try { data = Object.assign(data, event.data.json()); } catch(e) {}

  event.waitUntil(
    self.registration.showNotification(data.title, {
      body: data.body,
      icon: '/icon-192.png',
      badge: '/icon-192.png',
      data: { url: data.url || '/' }
    })
  );
});

// Clic sur la notification → ouvre (ou remet au premier plan) l'app
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetUrl = (event.notification.data && event.notification.data.url) || '/';
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientsArr) => {
      for (const client of clientsArr) {
        if ('focus' in client) return client.focus();
      }
      if (self.clients.openWindow) return self.clients.openWindow(targetUrl);
    })
  );
});
