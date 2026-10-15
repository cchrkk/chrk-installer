// Worker Cloudflare: serve dist/Ninite-Custom.ps1 su https://s.chrk.tk
// Vedi docs/publishing.md (Modo B).

const RAW = "https://raw.githubusercontent.com/cchrkk/ninite-custom/main/dist/Ninite-Custom.ps1";

export default {
  async fetch() {
    const r = await fetch(RAW, { cf: { cacheTtl: 300, cacheEverything: true } });
    return new Response(r.body, {
      status: r.status,
      headers: {
        "content-type": "text/plain; charset=utf-8",
        "cache-control": "public, max-age=300",
      },
    });
  },
};
