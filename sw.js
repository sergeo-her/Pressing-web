// Service Worker — PWA + notifications push natives (Web Push / VAPID)
const SW_VERSION = "pc-push-v2";

self.addEventListener("install", (event) => {
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener("fetch", () => {
  // Pas de cache agressif : toujours le réseau pour l'app
});

self.addEventListener("push", (event) => {
  let data = {
    title: "Pressing Connecté",
    body: "Nouvelle notification",
    url: "/",
    tag: "pressing-connecte"
  };
  try {
    if (event.data) {
      const parsed = event.data.json();
      data = Object.assign(data, parsed);
    }
  } catch (e) {
    try {
      data.body = event.data ? event.data.text() : data.body;
    } catch (_) {}
  }

  const options = {
    body: data.body || "",
    icon: "/icon-192.png",
    badge: "/icon-192.png",
    image: data.image || undefined,
    tag: data.tag || "pressing-connecte",
    renotify: true,
    requireInteraction: !!data.requireInteraction,
    vibrate: [120, 60, 120],
    data: { url: data.url || "/" },
    actions: data.actions || [
      { action: "open", title: "Ouvrir" },
      { action: "dismiss", title: "Fermer" }
    ]
  };

  event.waitUntil(self.registration.showNotification(data.title || "Pressing Connecté", options));
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  if (event.action === "dismiss") return;

  const targetUrl = (event.notification.data && event.notification.data.url) || "/";
  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ("focus" in client) {
          client.focus();
          if (client.navigate && targetUrl) {
            try { client.navigate(targetUrl); } catch (_) {}
          }
          return;
        }
      }
      if (self.clients.openWindow) return self.clients.openWindow(targetUrl);
    })
  );
});

self.addEventListener("pushsubscriptionchange", (event) => {
  // Le client se réabonnera au prochain chargement de l'app
  event.waitUntil(Promise.resolve());
});
