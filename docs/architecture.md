# Architettura

## Visione d'insieme

```
        dati                       build                        artefatto
┌────────────────────┐      ┌──────────────────┐      ┌────────────────────────┐
│ catalog-mine.json  │      │                  │      │                        │
│ ez.json            │─────▶│   build.ps1      │─────▶│  dist/CHRK-Installer.ps1│
│ extras.json        │      │   (+ rete)       │      │  (autocontenuto, GUI)  │
│ names.json         │      │                  │      └────────────────────────┘
│ mousefixes.inc     │      │ chrk-installer   │                  │
│ assets/logo.png    │      │ .template.ps1    │                  ▼
└────────────────────┘      └──────────────────┘                  su GitHub,
                                                                  servito via
        winstall.app/express ─┐                                   Cloudflare ez.chrk.tk
        WinUtil catalog      ─┘  (nomi + descrizioni)
```

`dist/CHRK-Installer.ps1` non ha dipendenze esterne: catalogo e logo sono **dentro** il file.

## Il file distribuito

- Parametri CLI (`-Preset`, `-Console`, `-InstallCron`, `-SelfUpdate`, ...).
- Auto-install: se eseguito in memoria (`irm | iex`), copia se stesso in
  `%LOCALAPPDATA%\CHRK-Installer\` e si riavvia da li' (serve per cronjob e self-update).
- GUI WinForms: barra superiore (logo, titolo, ricerca, azioni), **rail delle categorie** a
  sinistra, lista a destra con l'intestazione di ogni categoria (niente `GroupBox`: le voci
  sono `CheckBox` in un `FlowLayoutPanel` filtrato), pannello descrizione a destra, log +
  progresso in basso. La sezione **Aggiornamenti automatici** e' una voce del rail e si apre
  dentro l'area della lista.
- Motore winget: un processo `winget` per pacchetto, con mappa degli exit code.
- Motore registro: scrive le curve `SmoothMouseX/YCurve` e le soglie.
- Cronjob: `Register-ScheduledTask` (per default **non** elevato) + log su file. Ha
  `StartWhenAvailable` (recupera l'esecuzione saltata a PC spento) **ma** anche `RunOnlyIfIdle`
  con `IdleDuration` 10 minuti: parte solo quando il PC e' fermo, mai mentre giochi. Se torni
  al PC a meta' (`StopOnIdleEnd = false`) lo lascia finire invece di ucciderlo.

## Esecuzione (threading)

```
UI thread (STA, WinForms)
   │  click "APPLICA"
   ▼
Start-Worker ──▶ Runspace MTA (PowerShell remoto)
   │                 │  foreach voce:
   │                 │    winget install / Set-ItemProperty
   │                 │    Emit @{ t='pkg'|'res'|'scan'|'done'; ... }
   │                 ▼
   │            ConcurrentQueue[object]
   ▼
System.Windows.Forms.Timer (150 ms) → Drain-Queue
   scrive nel log colorato, aggiorna progress bar, %, media, ETA, conteggi
```

Regole:
- la runspace **non** tocca i controlli: mette solo messaggi nella coda;
- la UI non fa mai I/O bloccante (neanche `winget list`, che gira nello scan worker);
- `Test-Busy` (`$script:Handle.IsCompleted`) impedisce due lavori in parallelo.

## Modello dati di una voce

```powershell
@{ id = 'Git.Git'; name = 'Git'; cat = 'Sviluppo'; desc = '...'; pub = '...'
   src = 'winget'; preset = 'mine'|'extra'|''; ez = '1'|''; kind = 'pkg' }
```

`kind` decide cosa fa `APPLICA`:

| `kind` | da dove | cosa fa |
|---|---|---|
| `pkg` | catalogo (winget) | `winget install --id ...` |
| `mouse` | `mousefixes.inc` | curve MarkC nel registro |
| `tweak` | `tweaks.inc` (`ops`) | valori di registro (o `remove = 1` per toglierli) |
| `cmd` | `tweaks.inc` (`cmd`) | apre il comando in una finestra PowerShell elevata (MAS, WinUtil) |

Per i fix mouse (`kind = 'mouse'`) ci sono invece `scale`, `sens`, `x`, `y`, `speed`,
`t1`, `t2` e `desc`.

`preset` distingue la lista dell'autore (`mine`, da `catalog-mine.json`) dagli extra scelti a
mano (`extra`, da `extras.json`); `ez = '1'` marca le app di base consigliate
(`build/ez.json`, la guida `x.chrk.tk/ez`), che sono un preset a se'
(`Get-Preset recommended`) e possono coincidere con le altre. `kind` decide cosa fare quando
la voce viene applicata.

## Categorie

L'ordine delle sezioni nella GUI e' l'ordine di `$catOrder` in `build/build.ps1`; la
classificazione avviene con `Get-Cat` (una catena di regex, la prima che matcha vince).
Le regole sono `^(...)(?:\.|$)` — vedi la nota in `AGENTS.md`.

## Exit code winget gestiti

| Codice | Significato | Esito |
|---|---|---|
| `0` | ok | `OK` |
| `3010`, `1641`, `-1978334967`, `-1978334965` | installato, serve riavvio | `OK` |
| `-1978335135` | gia' installato | `SKIP` |
| `-1978335189` | nessun aggiornamento | `SKIP` |
| `-1978335107` (`APPINSTALLER_CLI_ERROR_ADMIN_CONTEXT_ACTION_PROHIBITED`) | pacchetto per-utente, non toccabile da elevato | `SKIP` |
| altro | errore | `FAIL` + `0x…` |

E' il motivo per cui il task pianificato gira **non elevato**: da elevato winget non vede
i pacchetti installati per-utente.

## Sicurezza

- Lo script non scarica nulla a runtime (tranne `-SelfUpdate`).
- Il comando `irm <url> | iex` esegue codice remoto: e' il modello di WinUtil, ma va
  pubblicato su un URL che controlli tu.
- Nessuna credenziale nel repo.
