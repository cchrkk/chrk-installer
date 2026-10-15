# Changelog

Il formato segue [Keep a Changelog](https://keepachangelog.com/it/1.1.0/);
la versione vive nel file `VERSION`.

## [1.1.0] - 2026-10-15

### Cambiato
- Il progetto si chiama **CHRK Installer** (prima "Ninite-Custom"): repo, artefatto
  `dist/CHRK-Installer.ps1`, cartella `%LOCALAPPDATA%\CHRK-Installer\`, task pianificato
  `CHRK-Installer Update` e log `chrk-update.log`.
- **GUI rifatta**: rail delle categorie a sinistra, lista con l'intestazione di ogni
  categoria (prima le `GroupBox` si rompevano e le sezioni non si vedevano), ricerca,
  "seleziona i visibili" e conteggio dei selezionati.
- **Prefissi `[CHRK.]` e `[extra]` rimossi** dai nomi: sono entrambi parte dell'unico preset
  `Consigliati` (`-Preset recommended`; `mine` ed `extra` restano alias), e la voce
  "consigliata" si legge nel pannello di destra.
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
