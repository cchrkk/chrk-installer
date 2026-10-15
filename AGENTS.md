# AGENTS.md

Istruzioni per chi (persona o agente AI) mette le mani in questa repo.

## In una frase

`build/build.ps1` legge dei dati (catalogo app + fix mouse + logo + template) e produce
`dist/Ninite-Custom.ps1`, un **unico file PowerShell autocontenuto** con GUI WinForms che
installa/aggiorna app via winget.

## Regola d'oro

> **Non modificare mai `dist/Ninite-Custom.ps1` a mano.**
> Si genera da `build/`. Ogni modifica manuale va persa al prossimo build.

Flusso: modifica `build/*` → esegui `.\build\build.ps1` → committa sia `build/` sia `dist/`.

## Mappa del codice

| File | Ruolo | Note |
|---|---|---|
| `build/ninite.template.ps1` | sorgente dello script distribuito | contiene i placeholder |
| `build/build.ps1` | compilatore | unisce dati + template |
| `build/catalog-mine.json` | export `winget export` dell'autore | preset `CHRK.` |
| `build/extras.json` | array di id winget | preset `Extra` |
| `build/names.json` | mappa `id minuscolo → {name, desc}` | usata quando winstall/WinUtil non hanno il pacchetto |
| `build/mousefixes.inc` | righe letterali dei fix mouse | generato da MarkC, vedi `docs/mousefixes.md` |
| `build/assets/logo.png` | logo | embeddato in base64 nel build |
| `tools/export-winget.ps1` | rigenera `catalog-mine.json` | da lanciare sul PC dell'autore |

### Placeholder nel template

`build.ps1` sostituisce, e **fallisce se non li trova**:

| Placeholder | Sostituito con |
|---|---|
| `__PACKAGES__` | le righe `@{ id = ...; name = ...; cat = ...; ... }` di tutte le voci |
| `__LOGO_B64__` | il logo in base64 |
| `__VERSION__` | la versione (parametro o file `VERSION`) |
| `__UPDATE_URL__` | l'URL pubblico per `-SelfUpdate` (default `https://s.chrk.tk`) |

## Vincoli tecnici da rispettare

1. **Solo ASCII nei `.ps1`.**
   PowerShell 5.1 legge i file senza BOM come ANSI: un carattere accentato corrompe il file
   e i build successivi. Per questo i commenti usano apostrofi (`e'`, `gia'`), non `è`/`à`.
   Le eccezioni (README, docs) sono `.md` e possono avere accenti.
2. **PowerShell 5.1 compatibile.** Niente `??`, `?.`, ternari `? :`, `-Parallel`.
   Usare `[Math]::Max`, `if` come espressione, `[System.Windows.Forms]`/`Drawing` (non WPF).
3. **WinForms senza fronzoli.** Non esistono `TextBox.PlaceholderText` ne' i colori su
   `TextBox`: per il log colorato serve `RichTextBox`.
4. **La lista pacchetti diventa oggetti.** In `ninite.template.ps1` le voci sono hashtable
   e subito dopo vengono convertite con `[pscustomobject]$_`, perche' `Group-Object` e
   `-ExpandProperty` non funzionano sulle hashtable.
5. **`ConcurrentQueue` + `Timer`.** Il lavoro (winget/registro) gira in una runspace MTA e
   comunica con la GUI solo tramite una coda drainata da un `System.Windows.Forms.Timer`
   ogni 150 ms. Non toccare la UI dalla runspace.
6. **Regex di classificazione: attenzione al punto finale.**
   Le regole sono `^(A|B|C)(?:\.|$)` e **non** `^(A|B|C)\.`.
   Un'alternativa che contiene gia' un punto (es. `Git\.`) rompe la regola: usa `Git`.
   Se aggiungi una regola, verifica che `Altre app` resti vuoto (il build lo segnala).

## Attivita' comuni

### Aggiungere una categoria

1. Aggiungi la regola in `Get-Cat` di `build/build.ps1` (ordine = priorita').
2. Aggiungi il nome in `$catOrder` nella stessa posizione desiderata nella GUI.
3. Ricompila e controlla che il conteggio abbia senso.

### Aggiungere un pacchetto al preset Extra

Aggiungi l'id winget in `build/extras.json`. Se winstall/WinUtil non lo conoscono, aggiungi
nome e descrizione in `build/names.json`.

### Aggiornare il preset CHRK.

Su un PC con le app installate:

```powershell
.\tools\export-winget.ps1
```

Poi ricompila. Lo script aggiorna `build/catalog-mine.json` e produce una lista di app non
reinstallabili via winget (`apps-manuali.md`).

### Aggiornare i fix mouse

Sostituisci/estrai lo zip MarkC e rigenera `build/mousefixes.inc`
(procedura in `docs/mousefixes.md`), poi ricompila.

### Nuova versione

1. Aggiorna `VERSION`.
2. `.\build\build.ps1`
3. Aggiorna `CHANGELOG.md` e committa `build/` + `dist/`.

La versione serve all'auto-aggiornamento: viene confrontata con quella scaricata.

## Checklist prima di un commit

- [ ] `.\build\build.ps1` termina senza warning (in particolare: nessun "winstall non ha risposto"
      e nessuna voce in `Altre app`).
- [ ] `Sintassi OK`: il build non lo verifica da solo, quindi
      `[void][System.Management.Automation.Language.Parser]::ParseFile('dist\Ninite-Custom.ps1',[ref]$null,[ref]$e)`
- [ ] Nessun `.ps1` contiene caratteri non-ASCII.
- [ ] `.\dist\Ninite-Custom.ps1 -Console -Preset mouse -DryRun` mostra il fix della scala giusta.
- [ ] `.\dist\Ninite-Custom.ps1 -ShowVersion` stampa la versione di `VERSION`.
- [ ] La GUI si apre senza errori (anche solo per pochi secondi).
- [ ] `dist/Ninite-Custom.ps1` e' stato ricompilato (non committare `build/` senza `dist/`).

## Cose da NON fare

- Non committare `dist/*.bak`, log (`ninite-update.log`) o credenziali.
- **Mai** committare token Cloudflare, GitHub o altro: `.gitignore` copre `.cf-token`,
  `*.token`, `.env`.
- Non introdurre dipendenze esterne a runtime: lo script deve funzionare con PowerShell 5.1
  e `winget` e basta.
- Non usare `-RunLevel Highest` come default per il task pianificato: winget non vede i
  pacchetti installati per-utente quando e' elevato.
- Non rimuovere il blocco di auto-install in memoria: e' cio' che permette il comando unico
  `irm s.chrk.tk | iex`.
