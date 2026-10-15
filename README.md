# CHRK Installer

Installer personale con **winget** (GUI WinForms), piu' una manciata di tweak di registro
(fix mouse MarkC). Un solo file `.ps1` autocontenuto.

```
irm https://s.chrk.tk | iex
```

![CHRK Installer](build/assets/logo.png)

## Cosa fa

- **Rail delle categorie a sinistra** (Browser, Documenti, Sviluppo, Mouse, ...) e lista a
  destra con le intestazioni di categoria, ricerca e descrizione di ogni voce passando il
  mouse.
- **Rileva cosa e' gia' installato** e lo salta (segna le voci come `(gia installato)`).
- **Avanzamento chiaro**: pacchetto corrente, `n/totale`, percentuale, media per pacchetto,
  ETA ed esito di ogni voce (`OK` / `SKIP` / `FAIL` con motivo).
- **Preset** (rail, *SELEZIONE RAPIDA*): `Consigliati` (la base della guida
  [x.chrk.tk/ez](https://x.chrk.tk/ez): browser, VLC, 7zip, Steam, Git, editor, utility),
  `CHRK.` (la lista dell'autore), `Extra` (scelte a mano), `Mouse fix`, piu' `Pulisci
  selezione` nell'intestazione della lista.
- **Aggiornamento automatico**: sezione dedicata dentro la lista - crea/rimuove il task di
  Windows che esegue `winget upgrade --all` ogni N giorni all'ora scelta, con lo stato e la
  prossima esecuzione in chiaro.
- **Fix mouse MarkC** selezionabili: 1:1 @6/11 per la propria scala DPI (rilevata), emulazioni
  W95/98 e W2K, disattivazione accelerazione su login, ripristino default.
- **Auto-aggiornamento**: `-SelfUpdate` o il pulsante nella GUI.

## Installazione

```powershell
# un comando (scarica, si auto-installa in %LOCALAPPDATA% e parte)
irm https://s.chrk.tk | iex

# con preset
& ([ScriptBlock]::Create((irm 'https://s.chrk.tk'))) -Preset recommended

# scaricando il file
irm https://s.chrk.tk -OutFile "$env:USERPROFILE\CHRK-Installer.ps1"
& "$env:USERPROFILE\CHRK-Installer.ps1"
```

## Uso da riga di comando

```powershell
.\CHRK-Installer.ps1                        # GUI
.\CHRK-Installer.ps1 -Preset recommended    # GUI, app consigliate preselezionate
.\CHRK-Installer.ps1 -Preset mouse          # rileva la scala DPI e preseleziona il fix giusto
.\CHRK-Installer.ps1 -Console               # elenco completo a console
.\CHRK-Installer.ps1 -Console -Preset recommended -DryRun
.\CHRK-Installer.ps1 -Select 'Git.Git','mouse-1to1-100' -Console
.\CHRK-Installer.ps1 -UpgradeAll            # aggiorna tutto (usato dal cronjob)
.\CHRK-Installer.ps1 -ShowVersion
.\CHRK-Installer.ps1 -SelfUpdate
.\CHRK-Installer.ps1 -InstallCron -EveryDays 7 -CronTime 03:00
.\CHRK-Installer.ps1 -RemoveCron
```

| Parametro | Effetto |
|---|---|
| `-Preset recommended\|ez\|mine\|extra\|mouse\|all\|none` | preselezione (`recommended` e `ez` = base consigliata; `mine` = lista dell'autore; `extra` = extra) |
| `-Select <id,id>` | selezione esplicita |
| `-Console` | niente GUI |
| `-DryRun` | non modifica nulla, mostra cosa farebbe |
| `-ForceReinstall` | reinstalla anche cio' che risulta presente |
| `-UpgradeAll` | `winget upgrade --all` |
| `-InstallCron` / `-RemoveCron` | gestione task pianificato |
| `-CronElevated` | task elevato (richiede admin, sconsigliato con winget) |
| `-SelfUpdate` / `-ShowVersion` | aggiornamento e versione |
| `-NoSelfInstall` | se eseguito in memoria, non si copia su disco |

## Come e' fatto il repository

```
├─ VERSION                          versione corrente (la usa il build)
├─ dist/CHRK-Installer.ps1          ARTEFATTO pubblicato (autocontenuto, non modificare a mano)
├─ build/
│  ├─ build.ps1                     compila dist/ partendo dai dati sotto
│  ├─ chrk-installer.template.ps1   sorgente dello script, con i placeholder
│  ├─ catalog-mine.json             export winget dell'autore -> preset "CHRK."
│  ├─ ez.json                       app di base consigliate (guida x.chrk.tk/ez)
│  ├─ extras.json                   pacchetti extra (preset "Extra")
│  ├─ names.json                    nomi/descrizioni manuali di riserva
│  ├─ mousefixes.inc                fix mouse MarkC gia' estratti
│  └─ assets/logo.png|svg           logo (png = embeddato)
├─ docs/                            architettura, pubblicazione, fix mouse
├─ tools/export-winget.ps1          rigenera catalog-mine.json + lista app manuali
├─ tools/shots.ps1                  (dev) avvia la GUI e ne salva uno screenshot
└─ .github/workflows/               build automatico
```

Per ricompilare:

```powershell
.\build\build.ps1                     # usa VERSION
.\build\build.ps1 -Version 1.1.0
```

## Pubblicazione

Vedi **[docs/publishing.md](docs/publishing.md)**: repo GitHub + proxy Cloudflare su
`s.chrk.tk` (redirect o Worker).

## Crediti e licenza

- Logica di install via winget derivata da [WinUtil](https://github.com/ChrisTitusTech/winutil) (MIT).
- Descrizioni app da [winstall.app](https://winstall.app) e dal catalogo WinUtil.
- Fix mouse: **MarkC Mouse Acceleration Fix Builder** (valori di registro, vedi
  [docs/mousefixes.md](docs/mousefixes.md)).
- Codice di questo progetto: [MIT](LICENSE).

> Ninite e' un marchio di Ninite LLC. Questo progetto non e' affiliato.
