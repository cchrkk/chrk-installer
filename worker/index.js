// Worker Cloudflare per https://ez.chrk.tk
//
// Un solo host, due cose:
//   - aperto da un browser  -> la guida FORMAT EZ (Accept: text/html)
//   - chiesto da irm/curl   -> lo script dell'installer (text/plain, cosi' iex lo esegue)
//
// Forzature utili:
//   /guide  o  ?html   -> guida
//   /installer.ps1     -> script
//   /version           -> solo la versione pubblicata

const REPO = "cchrkk/chrk-installer";
const BRANCH = "main";
const RAW = "https://raw.githubusercontent.com/" + REPO + "/" + BRANCH + "/";
const SCRIPT_URL = RAW + "dist/CHRK-Installer.ps1";
const GUIDE_URL = RAW + "docs/format-ez.html";
const ASSETS = RAW + "docs/assets/";

const TIPI = {
  svg: "image/svg+xml",
  png: "image/png",
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  webp: "image/webp",
  ico: "image/x-icon",
  css: "text/css; charset=utf-8",
  js: "text/javascript; charset=utf-8",
};

const CACHE = { cf: { cacheTtl: 300, cacheEverything: true } };

// il raw ogni tanto fa i capricci a freddo: un paio di tentativi e via
async function get(url, tries = 3) {
  let last = null;
  for (let i = 1; i <= tries; i++) {
    try {
      const r = await fetch(url, CACHE);
      if (r.ok) return r;
      last = r;
    } catch (e) {
      last = e;
    }
    await new Promise((res) => setTimeout(res, 150 * i));
  }
  return last;
}

function respond(body, type) {
  return new Response(body, {
    status: 200,
    headers: {
      "content-type": type,
      "cache-control": "public, max-age=300",
      "x-content-type-options": "nosniff",
    },
  });
}

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const path = (url.pathname.replace(/\/+$/, "") || "/").toLowerCase();
    const accept = request.headers.get("accept") || "";

    let what;
    if (path === "/guide" || path === "/guida" || url.searchParams.has("html")) {
      what = "html";
    } else if (path === "/installer.ps1" || path === "/script" || url.searchParams.has("raw")) {
      what = "ps1";
    } else if (path === "/version") {
      what = "version";
    } else if (path.indexOf("/assets/") === 0) {
      what = "asset";
    } else if (/text\/html/i.test(accept)) {
      // un browser apre la guida
      what = "html";
    } else {
      // irm / curl / PowerShell: lo script
      what = "ps1";
    }

    if (what === "asset") {
      const nome = url.pathname.slice("/assets/".length);
      if (!/^[A-Za-z0-9._-]+$/.test(nome)) return new Response("no", { status: 404 });
      const r = await get(ASSETS + nome);
      if (!r || !r.ok) return new Response("asset non trovato\n", { status: 404 });
      const ext = (nome.split(".").pop() || "").toLowerCase();
      return new Response(await r.arrayBuffer(), {
        status: 200,
        headers: {
          "content-type": TIPI[ext] || "application/octet-stream",
          "cache-control": "public, max-age=600",
          "x-content-type-options": "nosniff",
        },
      });
    }

    if (what === "version") {
      const r = await get(SCRIPT_URL);
      if (!r || !r.ok) return respond("?\n", "text/plain; charset=utf-8");
      const txt = await r.text();
      const m = txt.match(/\$script:Version\s*=\s*'([^']+)'/);
      return respond((m ? m[1] : "?") + "\n", "text/plain; charset=utf-8");
    }

    if (what === "html") {
      const r = await get(GUIDE_URL);
      if (!r || !r.ok) {
        // se la guida non c'e', almeno non lasciare il browser a mani vuote
        const why = r && r.status ? r.status : "rete";
        return respond(
          "<!doctype html><meta charset=utf-8><p>Guida non disponibile (" + why + "). " +
            'Lo script invece c\'e\': <code>irm ez.chrk.tk | iex</code></p>',
          "text/html; charset=utf-8"
        );
      }
      return respond(await r.text(), "text/html; charset=utf-8");
    }

    const r = await get(SCRIPT_URL);
    if (!r || !r.ok) {
      const why = r && r.status ? "HTTP " + r.status : "rete";
      return respond(
        "Download dello script non riuscito (" + why + "). Riprova, oppure prendilo da " +
          "https://github.com/" + REPO + "/blob/" + BRANCH + "/dist/CHRK-Installer.ps1\n",
        "text/plain; charset=utf-8"
      );
    }
    return respond(await r.text(), "text/plain; charset=utf-8");
  },
};
