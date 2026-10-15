# Ninite-Custom

Installer personale in stile **Ninite**, ma con **winget**, piu' una manciata di tweak di
registro (fix mouse MarkC). Un solo file `.ps1` autocontenuto con GUI.

```
irm https://s.chrk.tk | iex
```

![Ninite-Custom](build/assets/logo.png)

## Cosa fa

- **Lista selezionabile** di ~200 app winget, in sezioni con nome, ordinate e con descrizione
  visibile passando il mouse.
- **Rileva cosa e' gia' installato** e lo salta (come Ninite).
- **Avanzamento chiaro**: pacchetto corrente, `n/totale`, percentuale, media per pacchetto,
  ETA ed esito di ogni voce (`OK` / `SKIP` / `FAIL` con motivo).
- **Preset**: `CHRK.` (i pacchetti dell'autore), `Extra`, `Mouse fix`.
- **Fix mouse MarkC** selezionabili: 1:1 @6/11 per la propria scala DPI (rilevata), emulazioni
  W95/98 e W2K, disattivazione accelerazione su login, ripristino default.
- **Cronjob**: crea un task di Windows che esegue `winget upgrade --all` ogni N giorni.
- **Auto-aggiornamento**: `-SelfUpdate` o il pulsante nella GUI.

## Installazione

```powershell
# un comando (scarica, si auto-installa in %LOCALAPPDATA% e parte)
irm https://s.chrk.tk | iex

# con preset
& ([ScriptBlock]::Create((irm 'https://s.chrk.tk'))) -Preset mine

# scaricando il file
irm https://s.chrk.tk -OutFile "$env:USERPROFILE\Ninite-Custom.ps1"
& "$env:USERPROFILE\Ninite-Custom.ps1"
```

## Uso da riga di comando

```powershell
.\Ninite-Custom.ps1                        # GUI
.\Ninite-Custom.ps1 -Preset mine           # GUI, preset CHRK.
.\Ninite-Custom.ps1 -Preset extra
.\Ninite-Custom.ps1 -Preset mouse          # rileva la scala DPI e preseleziona il fix giusto
.\Ninite-Custom.ps1 -Console               # elenco completo a console
.\Ninite-Custom.ps1 -Console -Preset extra -DryRun
.\Ninite-Custom.ps1 -Select 'Git.Git','mouse-1to1-100' -Console
.\Ninite-Custom.ps1 -UpgradeAll            # aggiorna tutto (usato dal cronjob)
.\Ninite-Custom.ps1 -ShowVersion
.\Ninite-Custom.ps1 -SelfUpdate
.\Ninite-Custom.ps1 -InstallCron -EveryDays 7 -CronTime 03:00
.\Ninite-Custom.ps1 -RemoveCron
```

| Parametro | Effetto |
|---|---|
| `-Preset mine\|extra\|mouse\|all\|none` | preselezione |
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
├─ VERSION                  versione corrente (la usa il build)
├─ dist/Ninite-Custom.ps1   ARTEFATTO pubblicato (autocontenuto, non modificare a mano)
├─ build/
│  ├─ build.ps1             compila dist/ partendo dai dati sotto
│  ├─ ninite.template.ps1   sorgente dello script, con i placeholder
│  ├─ catalog-mine.json     export winget -> preset "CHRK."
│  ├─ extras.json           pacchetti extra del preset "Extra"
│  ├─ names.json            nomi/descrizioni manuali di riserva
│  ├─ mousefixes.inc        fix mouse MarkC gia' estratti
│  └─ assets/logo.png|svg   logo (png = embeddato)
├─ docs/                    architettura, pubblicazione, fix mouse
├─ tools/export-winget.ps1  rigenera catalog-mine.json + lista app manuali
└─ .github/workflows/       build automatico
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
