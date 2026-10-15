# Pubblicazione

Tre pezzi: **l'artefatto su GitHub**, **la guida su GitHub Pages** e **`ez.chrk.tk` su
Cloudflare**.

## 1. GitHub

```powershell
cd <cartella della repo>
git init -b main
git add .
git commit -m "CHRK-Installer v1.0.0"
git remote add origin https://github.com/cchrkk/chrk-installer.git
git push -u origin main
```

Dopo il push, l'artefatto e' gia' raggiungibile (raw):

```
https://raw.githubusercontent.com/cchrkk/chrk-installer/main/dist/CHRK-Installer.ps1
```

> Il repo **deve** contenere `dist/CHRK-Installer.ps1` (e' il file che viene servito).

### Release (opzionale ma consigliato)

```powershell
git tag v1.4.1
git push origin v1.4.1
```

La workflow `.github/workflows/build.yml` ricompila e allega l'artefatto alla release.

## 1b. GitHub Pages — la cartella `docs/`

Il repo ha **Pages attivo** con sorgente *branch `main`, cartella `/docs`*: tutto quello che
sta in `docs/` e' servito come sito statico.

```
https://cchrkk.github.io/chrk-installer/                 -> docs/index.html (landing)
https://cchrkk.github.io/chrk-installer/format-ez.html   -> la guida FORMAT EZ (HTML)
https://bio.chrk.tk/chrk-installer/format-ez.html        -> lo stesso, sul dominio custom
                                                            dell'account Pages
```

Basta committare in `docs/` e pushare: Pages ricostruisce da solo. Serve perche'
`raw.githubusercontent.com` risponde `text/plain`: una pagina HTML li' il browser la mostra
come testo.

## 2. Cloudflare — `ez.chrk.tk`: un host, due cose

Cosa gira adesso (15/10/2026): un **Worker** su `ez.chrk.tk` che guarda l'header `Accept`.

| Richiesta | Risposta |
|---|---|
| browser (`Accept: text/html`) | la **guida** FORMAT EZ (`text/html`) |
| `irm ez.chrk.tk \| iex`, `curl`, `Invoke-WebRequest` | lo **script** dell'installer (`text/plain`, cosi' `iex` lo esegue) |
| `/guide` (o `?html`) | la guida, forzata |
| `/installer.ps1` (o `/raw`) | lo script, forzato |
| `/version` | solo la versione pubblicata |

Deploy (dalla cartella `worker/`, con `CLOUDFLARE_API_TOKEN` e `CLOUDFLARE_ACCOUNT_ID`
nell'ambiente):

```powershell
npx wrangler deploy
```

`worker/wrangler.toml` ha `routes = [{ pattern = "ez.chrk.tk", custom_domain = true }]`: il
record DNS lo crea Cloudflare da solo. Il codice e' `worker/index.js` (~90 righe, con un
paio di tentativi se il raw fa i capricci a freddo).

Verifica:

```powershell
# deve rispondere text/plain e iniziare con <#
curl.exe -sS -o NUL -w "%{http_code} %{content_type}`n" https://ez.chrk.tk

# deve rispondere text/html (la guida)
curl.exe -sS -o NUL -w "%{http_code} %{content_type}`n" -H "Accept: text/html" https://ez.chrk.tk

irm https://ez.chrk.tk/version      # versione servita
irm ez.chrk.tk | iex                # install completo
```

### `s.chrk.tk` (vecchio, ancora vivo)

Per non rompere chi ha il comando vecchio salvato da qualche parte, `s.chrk.tk` resta una
**Redirect Rule** della zona che manda (302) al raw di GitHub. Si configura con
`tools/setup-cloudflare.ps1` (default `-Hostname s`). **Non va piu' pubblicizzato**: il
comando buono e' `irm ez.chrk.tk | iex`.

> Due trappole gia' pagate (15/10/2026): due regole di redirect sullo stesso host **si
> annullano** (vince la prima), e il 302 **resta in cache** sull'edge finche' non fai
> `purge_cache`. Dettagli in `INFRA.md` → Cloudflare.

### Perche' `ez.chrk.tk` funziona anche senza schema

`Invoke-WebRequest` completa `ez.chrk.tk` in `http://ez.chrk.tk`, e con `always_use_https = on`
Cloudflare risponde con un upgrade a HTTPS. Quindi `irm ez.chrk.tk | iex` e' sufficiente.

## 3. Aggiornare la versione pubblicata

1. Alza `VERSION` e `.\build\build.ps1`
2. Commit + push di `build/` e `dist/`
3. Cache: col Worker `cacheTtl` e' 300s; per vederlo subito, `/version` con un query string
   a caso.

L'auto-aggiornamento dentro lo script confronta `$script:Version` con quello scaricato da
`$script:UpdateUrl` (= `https://ez.chrk.tk`), quindi basta ripubblicare.

## Sicurezza

- Il token Cloudflare **non** va committato ne' messo nella repo: si passa come variabile
  d'ambiente (`CF_API_TOKEN` / `CLOUDFLARE_API_TOKEN`); `tools/setup-cloudflare.ps1` legge
  `CF_API_TOKEN`.
- Preferisci un token **scoped** (Zone → DNS → Edit, Zone → Config Rules → Edit, Workers
  Scripts → Edit) invece di un token globale. Dopo l'uso, revocalo da
  *My Profile → API Tokens*.
