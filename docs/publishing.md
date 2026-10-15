# Pubblicazione

Due pezzi: **l'artefatto su GitHub** e **l'URL corto su Cloudflare** (`s.chrk.tk`).

## 1. GitHub

```powershell
cd <cartella della repo>
git init -b main
git add .
git commit -m "Ninite-Custom v1.0.0"
git remote add origin https://github.com/cchrkk/ninite-custom.git
git push -u origin main
```

Dopo il push, l'artefatto e' gia' raggiungibile (raw):

```
https://raw.githubusercontent.com/cchrkk/ninite-custom/main/dist/Ninite-Custom.ps1
```

> Il repo **deve** contenere `dist/Ninite-Custom.ps1` (e' il file che viene servito).
> Non serve GitHub Pages, ma e' un'alternativa valida (vedi in fondo).

### Release (opzionale ma consigliato)

```powershell
git tag v1.0.0
git push origin v1.0.0
```

La workflow `.github/workflows/build.yml` ricompila e allega l'artefatto alla release.

## 2. Cloudflare — `s.chrk.tk`

Zona: `chrk.tk` (gia' su Cloudflare, `always_use_https = on`, `ssl = strict`).

`irm s.chrk.tk | iex` deve ricevere **il contenuto dello script**. Ci sono due modi.

### Modo A — Redirect (semplice, consigliato)

Si crea un record DNS fittizio proxato e una Redirect Rule che manda tutto a GitHub raw.

**DNS**
| Tipo | Nome | Contenuto | Proxy |
|---|---|---|---|
| CNAME | `s` | `cchrkk.github.io` | Proxied |

**Redirect Rule** (Rules → Overview → Create rule → Redirect rule)

- When: `Hostname` `equals` `s.chrk.tk`
- Then: Dynamic redirect, Expression `concat("https://raw.githubusercontent.com/cchrkk/ninite-custom/main/dist/Ninite-Custom.ps1")`
- Status: `302`, spunta *Preserve query string* se ti serve
- Placement: **First** (o almeno prima delle altre regole che riguardano `s`)

Risultato: `http://s.chrk.tk` → 302 → HTTPS GitHub raw → PowerShell segue il redirect.

**Via API** (quello che fa `api`): vedi `tools/setup-cloudflare.ps1`.

### Modo B — Worker (proxy vero, senza redirect)

Il Worker scarica da GitHub e riscrive la risposta: l'URL resta `https://s.chrk.tk`
e si possono aggiungere endpoint e cache.

```powershell
# con wrangler, nella cartella worker/
npx wrangler deploy
```

`worker/wrangler.toml`:

```toml
name = "chrk-ninite"
main = "index.js"
compatibility_date = "2026-01-01"

routes = [{ pattern = "s.chrk.tk", custom_domain = true }]
```

`worker/index.js`:

```js
const RAW = "https://raw.githubusercontent.com/cchrkk/ninite-custom/main/dist/Ninite-Custom.ps1";

export default {
  async fetch(request) {
    const url = new URL(request.url);

    if (url.pathname === "/version") {
      const r = await fetch(RAW, { cf: { cacheTtl: 60, cacheEverything: true } });
      const txt = await r.text();
      const m = txt.match(/\$script:Version\s*=\s*'([^']+)'/);
      return new Response((m ? m[1] : "?") + "\n", {
        headers: { "content-type": "text/plain; charset=utf-8" },
      });
    }

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
```

Con il Worker **non serve** una Redirect Rule; basta il record DNS proxato
(`s` → qualunque origine, il Worker risponde prima) o il `custom_domain` in `wrangler.toml`.

### Perche' `s.chrk.tk` funziona anche senza schema

`Invoke-WebRequest` completa `s.chrk.tk` in `http://s.chrk.tk`, e con `always_use_https = on`
Cloudflare risponde con un upgrade a HTTPS. Quindi `irm s.chrk.tk | iex` e' sufficiente.

## 3. Verifica

```powershell
# cosa restituisce l'URL (deve essere il sorgente PowerShell)
(irm https://s.chrk.tk -UseBasicParsing).Substring(0,60)

# redirect
curl.exe -sI http://s.chrk.tk | Select-String -Pattern 'HTTP|location'

# versione servita (solo col Worker)
irm https://s.chrk.tk/version

# install completo
irm https://s.chrk.tk | iex
```

## 4. Aggiornare la versione pubblicata

1. Alza `VERSION` e `.\build\build.ps1`
2. Commit + push di `build/` e `dist/`
3. Cache: con raw GitHub la cache e' di qualche minuto; col Worker usa `cacheTtl` (300s) o
   fai purge dalla dashboard.

L'auto-aggiornamento dentro lo script confronta `$script:Version` con quello scaricato da
`$script:UpdateUrl`, quindi basta ripubblicare.

## Nota: GitHub Pages (alternativa senza Cloudflare)

Attiva Pages sul branch `main` (cartella `/dist`). Poi `s` puo' puntare direttamente a:

| Tipo | Nome | Contenuto | Proxy |
|---|---|---|---|
| CNAME | `s` | `cchrkk.github.io` | Proxied |

ma l'URL diventa `https://s.chrk.tk/Ninite-Custom.ps1` (il root servirebbe l'indice).
Col redirect del Modo A invece il root va gia' bene.

## Sicurezza

- Il token Cloudflare **non** va committato ne' messo nella repo: usa `CF_API_TOKEN`
  come variabile d'ambiente (`tools/setup-cloudflare.ps1` lo legge da li').
- Preferisci un token **scoped** (Zone → DNS → Edit, Zone → Config Rules → Edit) invece di
  un token globale. Dopo l'uso, revocalo da *My Profile → API Tokens*.
