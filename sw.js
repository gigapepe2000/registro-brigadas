const C = 'registro-v1';
const BASE = ['./', 'index.html', 'manifest.webmanifest',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.min.js'];

self.addEventListener('install', e => e.waitUntil(caches.open(C).then(c => c.addAll(BASE))));
self.addEventListener('activate', e => e.waitUntil(
  caches.keys().then(ks => Promise.all(ks.filter(k => k !== C).map(k => caches.delete(k))))));

// Primero la red (para recibir actualizaciones); si no hay cobertura, la copia guardada.
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET' || e.request.url.includes('supabase.co')) return;
  e.respondWith(fetch(e.request).then(r => {
    const copia = r.clone();
    caches.open(C).then(c => c.put(e.request, copia));
    return r;
  }).catch(() => caches.match(e.request)));
});
