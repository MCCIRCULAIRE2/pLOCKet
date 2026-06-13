const VERSION = '__BUILD_VERSION__';

self.addEventListener('install', (event) => {
  console.log('[SW] Install - Version:', VERSION);
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  console.log('[SW] Activate - Version:', VERSION);
  event.waitUntil(self.clients.claim());
});

self.addEventListener('message', (event) => {
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
  }
  if (event.data === 'getVersion' && event.ports && event.ports[0]) {
    event.ports[0].postMessage({ version: VERSION });
  }
});
