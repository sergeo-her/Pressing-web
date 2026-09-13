// Service worker minimal — rend l'app installable (critère PWA).
// Ne met rien en cache pour l'instant : chaque visite recharge la dernière
// version en ligne, ce qui évite les soucis de version périmée pendant
// que le projet évolue encore souvent.

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  // Laisse passer toutes les requêtes normalement (pas de cache pour l'instant).
});
