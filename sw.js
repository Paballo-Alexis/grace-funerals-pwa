const CACHE_VERSION = "parlour-shell-v1.0.0";
const SHELL_ASSETS = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./assets/css/tokens.css",
  "./assets/js/config.js",
  "./assets/js/pwa-queue.js",
  "./assets/media/hero-family-support-desktop.webp",
  "./assets/media/pkg-dignity-essential-card.webp",
  "./assets/media/pkg-family-sanctuary-card.webp",
  "./assets/media/pkg-complete-legacy-card.webp"
];

self.addEventListener("install", (event) => {
  console.log("[PWA:SW] Installing", CACHE_VERSION);
  event.waitUntil(
    caches.open(CACHE_VERSION).then((cache) => cache.addAll(SHELL_ASSETS))
  );
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  console.log("[PWA:SW] Activating", CACHE_VERSION);
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_VERSION).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) return cached;
      return fetch(event.request)
        .then((res) => {
          if (res.ok && res.type === "basic") {
            const copy = res.clone();
            caches.open(CACHE_VERSION).then((cache) => cache.put(event.request, copy));
          }
          return res;
        })
        .catch(() => caches.match("./index.html"));
    })
  );
});
