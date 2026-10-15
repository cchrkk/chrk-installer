# Changelog

Il formato segue [Keep a Changelog](https://keepachangelog.com/it/1.1.0/);
la versione vive nel file `VERSION`.

## [1.4.3] - 2026-10-15

### Cambiato
- **Guida HTML**: al posto del titolo "FORMAT EZ" c'e' il **logo chrk** (SVG, con inversione
  automatica sul tema scuro), "una guida **a cura di chrk.**", e al posto di "rev. 2k26" la
  **data di aggiornamento**. Font **Anonymous Pro** (Google Fonts) per titoli, etichette,
  tabelle e comandi; il corpo resta sans per leggibilita'. Torna lo spazio per le due
  immagini della guida (in cima e in fondo): `docs/assets/ez-top.png` e `ez-bottom.png`.
- **Worker**: serve anche `/assets/*` dal repo (logo e immagini della guida), con il
  content-type giusto - cosi' `ez.chrk.tk/assets/...` funziona.

## [1.4.2] - 2026-10-15

### Cambiato
- Nel preset **Consigliati** c'e' **un solo browser: Vivaldi**. Prima erano spuntati
  Chrome + Firefox + Brave in contemporanea, che non ha senso (15 app in tutto).
- **Via il comando `irm https://get.activated.win | iex` dalle guide**: la lista *ClickFix* di
  uBlock Origin lo segnala come attacco su una pagina web. MAS resta nell'installer
  (*Wizard e script*, che scarica `MAS_AIO.cmd`), e a mano basta scaricare quel file dal repo.

### Corretto
- L'id winget di Vivaldi nella guida era vecchio: `VivaldiTechnologies.Vivaldi` non esiste
  piu', quello giusto e' `Vivaldi.Vivaldi` (verificato con `winget search --exact`).

## [1.4.1] - 2026-10-15

### Cambiato
- **Il comando pubblicato e' ora `irm ez.chrk.tk | iex`**. `ez.chrk.tk` e' un Worker Cloudflare
  che guarda l'header `Accept`: da browser mostra la **guida FORMAT EZ** (HTML, con i bottoni
  Copia), da `irm`/`curl` serve lo **script** (`text/plain`, cosi' `iex` lo esegue), piu'
  `/guide`, `/installer.ps1` e `/version`.
- `-SelfUpdate` e `-UpdateUrl` puntano a `https://ez.chrk.tk`; README, AGENTS e guide
  aggiornati. `s.chrk.tk` resta vivo come redirect per chi ha il comando vecchio salvato.
- La guida FORMAT EZ e' anche su GitHub Pages (`docs/`, landing + guida).

## [1.4.0] - 2026-10-15

### Cambiato
- **La GUI parte con le app consigliate gia' spuntate** (le 17 della guida EZ): su un PC
  nuovo apri e premi `APPLICA SELEZIONATI`. Gia' installate restano escluse come sempre.
  Per aprire senza preselezione: `-Preset none`.
- In console la preselezione si applica **solo se la chiedi** (`-Preset ...` o `-Select ...`):
  un `-Console` secco continua a stampare solo il catalogo.

## [1.3.0] - 2026-10-15

### Cambiato
- **I wizard si aprono da soli, senza incollare niente.** Invece del comando `irm <url> | iex`
  (che Defender blocca perche' e' la firma tipica dei malware) l'installer scarica il
  **file ufficiale** del progetto e lo esegue da amministratore:
  - **MAS**: `MAS_AIO.cmd` dal repo `massgravel/Microsoft-Activation-Scripts`
    (`MAS/All-In-One-Version-KL/`, il file autosufficiente che la loro guida chiama
    "Method 2 - Traditional"), 744 KB;
  - **WinUtil**: `winutil.ps1` dall'ultima release di `ChrisTitusTech/winutil`, 928 KB.
  I file finiscono in `%LOCALAPPDATA%\CHRK-Installer\wizard\` e vengono riscaricati a ogni
  uso (cosi' hai sempre l'ultima versione).
- Se il download fallisce o Defender mette il file in quarantena, si ripiega da solo sul
  comando negli appunti (PowerShell da amministratore, Ctrl+V e Invio).
- Campi nuovi delle voci `kind = 'cmd'` in `build/tweaks.inc`: `url`, `file`, `runner`
  (`cmd` o `ps1`) e `switches`. Con `switches = '/HWID /S'` MAS partirebbe in modalita'
  non assistita.

## [1.2.1] - 2026-10-15

### Corretto
- **I wizard (MAS, WinUtil) ora si aprono come li apriresti tu**: una PowerShell **da
  amministratore** col comando negli appunti (Ctrl+V e Invio). Prima il comando veniva
  passato con `-Command "irm <url> | iex"` e **Windows Defender lo bloccava** - e' la firma
  tipica dei malware, mentre lo stesso comando digitato a mano passa.
  Per la cronaca, due vicoli ciechi verificati sul campo: incollare noi i tasti non funziona
  (verso una finestra elevata `SendKeys` viene bloccato da UIPI, perche' il nostro processo
  non e' elevato) e `Start-Process -Verb RunAs` **non eredita le variabili d'ambiente** (passa
  da ShellExecute), quindi nemmeno passare il comando per variabile funziona.

## [1.2.0] - 2026-10-15

### Aggiunto
- Sezione **Tweaks di Windows** nella lista (guida EZ, sezione 9): estensioni visibili in
  Explorer, file nascosti, Esplora file su "Questo PC", barra senza widget/chat/visualizzazione
  attivita, niente casella di ricerca ne' Bing, Copilot spento, niente suggerimenti e
  pubblicita in Start/Impostazioni, piu' **"Ripristina i valori originali di Windows"**.
- Sezione **Wizard e script**: **MAS** (attivazione Windows/Office) e **WinUtil** (debloat,
  tweak, app) si aprono in una finestra PowerShell **elevata**, come dice la guida.
- Le voci non-app hanno un `kind`: `tweak` (valori di registro, con `ops`) e `cmd` (wizard);
  vivono in `build/tweaks.inc`. Nel rail le sezioni non-app (Aggiornamenti automatici, Mouse,
  Tweaks di Windows, Wizard e script) stanno in cima, separate dalle categorie di app.

### Corretto
- I tweak non scrivevano **niente**: su una hashtable `$op.remove` non e' `$null` ma il metodo
  `Remove()`, quindi ogni operazione finiva nel ramo "cancella" e usciva senza errori. Ora i
  campi delle op si leggono con `Get-OpField` (`Contains()`/`PSObject.Properties`).

## [1.1.3] - 2026-10-15

### Aggiunto
- `build/exclude.json`: id da tenere fuori dal catalogo (primo uso: **Splashtop Business**
  rimosso).
- `build/guide.json`: le altre app consigliate dalla guida EZ, presenti nel catalogo ma fuori
  dal preset base - **O&O ShutUp10++**, **Logitech G HUB**, **Razer Synapse 4**,
  **Corsair iCUE 5**, **SteelSeries GG**, **Hasleo Backup Suite Free** (con nome,
  descrizione e categoria vere: la guida le cita senza id winget).
- `Consigliati` passa a 17 app: aggiunto **O&O ShutUp10++** (sezione 9 della guida).
- Nel pannello di destra la voce "dalla guida EZ" per le app di `guide.json`.

## [1.1.2] - 2026-10-15

### Corretto
- **`irm s.chrk.tk | iex` su un Windows appena installato**: la copia locale veniva lanciata
  con `& file.ps1` e con l'ExecutionPolicy di default (`Restricted`) PowerShell rifiutava di
  eseguirla, lasciando l'utente con un errore dopo il download. Ora l'installer alza la
  policy **solo per il proprio processo** (`Set-ExecutionPolicy -Scope Process Bypass`, non
  richiede admin) e, se a bloccare e' una policy di gruppo, esegue la copia locale in memoria
  dicendo chiaramente che cronjob e auto-aggiornamento restano spenti.

## [1.1.1] - 2026-10-15

### Corretto
- **Il blocco "SELEZIONE RAPIDA" non si vedeva affatto**: il pannello che lo contiene non
  veniva mai aggiunto al rail (colpa di un `Controls.Add` mancante). Il primo sintomo era
  "dov'e' il selettore dei consigliati?".

### Cambiato
- **`Consigliati` e `CHRK.` sono due preset diversi**: `Consigliati` (`-Preset recommended`,
  alias `ez`) e' la base della guida `x.chrk.tk/ez` (`build/ez.json`, 16 app: browser, VLC,
  7zip, Steam, Git, editor, utility), `CHRK.` resta la lista dell'autore e `Extra` le scelte
  a mano. `ez` e' un flag in piu' sulla voce, quindi un'app puo' stare in piu' preset.
- Al posto di "seleziona i visibili" (inutile) l'intestazione della lista ha
  **`Pulisci selezione`**, attivo solo quando c'e' qualcosa da pulire.

## [1.1.0] - 2026-10-15

### Cambiato
- Il progetto si chiama **CHRK Installer** (prima "Ninite-Custom"): repo, artefatto
  `dist/CHRK-Installer.ps1`, cartella `%LOCALAPPDATA%\CHRK-Installer\`, task pianificato
  `CHRK-Installer Update` e log `chrk-update.log`.
- **GUI rifatta**: rail delle categorie a sinistra, lista con l'intestazione di ogni
  categoria (prima le `GroupBox` si rompevano e le sezioni non si vedevano), ricerca e
  conteggio dei selezionati.
- **Prefissi `[CHRK.]` e `[extra]` rimossi** dai nomi delle app: l'appartenenza a un preset
  si legge nel pannello di destra.
- L'**aggiornamento automatico** non e' piu' una finestra: e' una sezione *dentro la lista*
  ("Aggiornamenti automatici" nel rail) con frequenza, orario, stato, prossima esecuzione e
  log, con `Salva impostazioni` / `Esegui adesso` / `Ricarica stato`.

### Corretto
- Il filtro della ricerca non blocca piu' la UI (il layout veniva ricalcolato 200+ volte a
  ogni tasto premuto).
- `-Preset none` non azzera piu' le selezioni fatte a mano mentre la scansione e' in corso.
- La barra di avanzamento compare solo quando c'e' un lavoro in corso.

## [1.0.2] - 2026-10-15

### Cambiato
- Nomi e descrizioni puliti per i pacchetti senza metadati (Android Studio, Arduino IDE,
  .NET Runtime/SDK, Windows App Runtime, Fedora Media Writer, ecc.).
- `Microsoft.Office` spostato in Documenti.

## [1.0.1] - 2026-10-15

### Cambiato
- Intestazione generica (niente riferimenti alla macchina dell'autore) per la pubblicazione.

## [1.0.0] - 2026-10-15

### Aggiunto
- GUI WinForms con logo embeddato, ricerca, filtri e pannello descrizione su hover.
- Catalogo unico categorizzato e ordinato: i pacchetti dell'autore (`CHRK.`), gli extra,
  e ~90 app popolari da winstall.app, con nome, descrizione e publisher.
- Avanzamento dettagliato: pacchetto corrente, `n/totale`, percentuale, media per
  pacchetto, ETA ed esito per voce.
- 15 fix mouse MarkC selezionabili (1:1 @6/11 per 9 scale DPI, emulazioni W95/98 e W2K,
  disattivazione accelerazione su login, ripristino default).
- Cronjob: task pianificato per `winget upgrade --all` (non elevato di default).
- Auto-aggiornamento (`-SelfUpdate`, pulsante in GUI).
- Comando unico: se eseguito in memoria lo script si installa in `%LOCALAPPDATA%`.
- Modalita' console con `-Console`, `-DryRun`, `-Select`.
- Repo con build riproducibile e documentazione per agenti (`AGENTS.md`).

### Note
- Richiede PowerShell 5.1 e `winget`.
- I fix mouse richiedono logoff/login per l'effetto completo.
