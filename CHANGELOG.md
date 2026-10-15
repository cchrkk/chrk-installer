# Changelog

Il formato segue [Keep a Changelog](https://keepachangelog.com/it/1.1.0/);
la versione vive nel file `VERSION`.

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
