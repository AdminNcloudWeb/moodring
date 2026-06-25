/* Moodring service worker — offline-first for the static shell.
 *
 * The app is already local-first (state lives in localStorage), so the only
 * job here is to cache the app shell so it launches with no network. Bump
 * CACHE_VERSION whenever a cached file changes to force an update.
 */
const CACHE_VERSION = 'moodring-v4';
const APP_SHELL = [
  './',
  './index.html',
  './privacy.html',
  './contact.html',
  './styles.css',
  './app.js',
  './config.js',
  './manifest.webmanifest',
  './apple-touch-icon.png',
  './icons/icon-192.png',
  './icons/icon-512.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_VERSION).then((cache) => cache.addAll(APP_SHELL))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE_VERSION).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  // Never cache Supabase API/auth traffic — always go to the network.
  if (url.hostname.endsWith('.supabase.co')) return;

  // Same-origin app shell: cache-first, falling back to network and updating
  // the cache opportunistically.
  if (url.origin === self.location.origin) {
    event.respondWith(
      caches.match(request).then((cached) => {
        const network = fetch(request).then((resp) => {
          if (resp && resp.status === 200 && resp.type === 'basic') {
            const copy = resp.clone();
            caches.open(CACHE_VERSION).then((cache) => cache.put(request, copy));
          }
          return resp;
        }).catch(() => cached);
        return cached || network;
      })
    );
  }
});
