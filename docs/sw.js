// O aplicativo exige internet. Não armazenar API, tokens ou lançamentos em cache.
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',event=>event.waitUntil(self.clients.claim()));
self.addEventListener('fetch',event=>{
  if(event.request.mode==='navigate' && new URL(event.request.url).origin===self.location.origin){
    event.respondWith(fetch(event.request).catch(()=>new Response('Finance Control precisa de conexão com a internet. Reconecte e atualize.',{status:503,headers:{'Content-Type':'text/plain; charset=utf-8'}})));
  }
});
