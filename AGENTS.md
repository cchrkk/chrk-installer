# AGENTS.md

Istruzioni per chi (persona o agente AI) mette le mani in questa repo.

## In una frase

`build/build.ps1` legge dei dati (catalogo app + fix mouse + logo + template) e produce
`dist/CHRK-Installer.ps1`, un **unico file PowerShell autocontenuto** con GUI WinForms che
installa/aggiorna app via winget.

## Regola d'oro

> **Non modificare mai `dist/CHRK-Installer.ps1` a mano.**
> Si genera da `build/`. Ogni modifica manuale va persa al prossimo build.

Flusso: modifica `build/*` → esegui `.\build\build.ps1` → committa sia `build/` sia `dist/`.

## Mappa del codice

| File | Ruolo | Note |
|---|---|---|
| `build/chrk-installer.template.ps1` | sorgente dello script distribuito | contiene i placeholder |
| `build/build.ps1` | compilatore | unisce dati + template |
| `build/catalog-mine.json` | export `winget export` dell'autore | preset `CHRK.` (`preset = 'mine'`) |
| `build/ez.json` | array di id winget | app di base `Consigliati` (`-Preset recommended`), dalla guida `x.chrk.tk/ez` |
| `build/guide.json` | array di id winget | le altre app della guida EZ: nel catalogo e selezionabili, ma fuori dal preset |
| `build/exclude.json` | array di id winget | id da **non** mettere nel catalogo (es. `Splashtop.SplashtopBusiness`) |
| `build/extras.json` | array di id winget | preset `Extra` (`preset = 'extra'`) |
| `build/names.json` | mappa `id minuscolo → {name, desc}` | usata quando winstall/WinUtil non hanno il pacchetto |
| `build/mousefixes.inc` | righe letterali dei fix mouse | generato da MarkC, vedi `docs/mousefixes.md` |
| `build/tweaks.inc` | righe letterali dei tweak di Windows e dei wizard | `kind = 'tweak'` (registro) e `kind = 'cmd'` (MAS, WinUtil) |
| `build/assets/logo.png` | logo | embeddato in base64 nel build |
| `tools/export-winget.ps1` | rigenera `catalog-mine.json` | da lanciare sul PC dell'autore |
| `tools/shots.ps1` | (dev) avvia la GUI e salva uno screenshot | per controllare la resa della UI |

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
4. **La lista pacchetti diventa oggetti.** In `chrk-installer.template.ps1` le voci sono hashtable
   e subito dopo vengono convertite con `[pscustomobject]$_`, perche' `Group-Object` e
   `-ExpandProperty` non funzionano sulle hashtable.
5. **`ConcurrentQueue` + `Timer`.** Il lavoro (winget/registro) gira in una runspace MTA e
   comunica con la GUI solo tramite una coda drainata da un `System.Windows.Forms.Timer`
   ogni 150 ms. Non toccare la UI dalla runspace.
6. **Regex di classificazione: attenzione al punto finale.**
   Le regole sono `^(A|B|C)(?:\.|$)` e **non** `^(A|B|C)\.`.
   Un'alternativa che contiene gia' un punto (es. `Git\.`) rompe la regola: usa `Git`.
   Se aggiungi una regola, verifica che `Altre app` resti vuoto (il build lo segnala).
7. **La lista pacchetti segue `$catOrder`.** In `chrk-installer.template.ps1` l'ordine delle
   sezioni e delle voci nel rail e' l'ordine in cui compaiono in `$Packages` (cioe' quello
   deciso da `$catOrder` in `build.ps1`). Non riordinare a mano nella GUI.
8. **Non tutte le voci sono app.** Il campo `kind` decide cosa fa `APPLICA`:
   `pkg` = `winget install`, `mouse` = curve MarkC, `tweak` = valori di registro (`ops`,
   vedi `build/tweaks.inc`), `cmd` = apre una PowerShell **da amministratore** col comando
   negli appunti (`MAS`, `WinUtil`: Ctrl+V e Invio lo fa l'utente). `tweak` e `cmd` vivono in
   `build/tweaks.inc`, righe letterali come i fix mouse; nel rail le sezioni non-app
   (Aggiornamenti automatici, Mouse, Tweaks di Windows, Wizard e script) stanno in cima,
   separate da una riga.
   **Trappola 1**: su una hashtable `$op.remove` **non e' `$null`**, e' il metodo `Remove()`
   della hashtable, quindi e' sempre "vero" e il tweak verrebbe trattato come una
   cancellazione. I campi di un'op si leggono sempre con `Get-OpField` (che usa
   `Contains()`/`PSObject.Properties`), mai con `$op.<campo>`.
   **Trappola 2 (wizard)**: passare `irm <url> | iex` sulla riga di comando (`-Command "..."`)
   fa scattare Defender, che lo blocca; digitato a mano passa. Per questo il comando finisce
   negli appunti e la finestra va aperta *senza* argomenti: `Start-Process -Verb RunAs`
   passa da ShellExecute e **non eredita le variabili d'ambiente**. Incollare noi i tasti
   non funziona comunque: verso una finestra elevata `SendKeys`/`SendInput` viene bloccato
   dal sistema (UIPI) perche' il nostro processo non e' elevato.

## La GUI, in breve

Sezione `# ==== GUI ====` di `chrk-installer.template.ps1`. Dall'esterno verso l'interno:

| Pezzo | Contenuto |
|---|---|
| `$top` (Dock=Top) | logo, titolo, ricerca, `reinstalla se presente`, `solo selezionati`, `APPLICA SELEZIONATI`, `Aggiorna tutto`, versione cliccabile |
| `$rail` (Dock=Left) | `$lstCats`: `ListBox` owner-draw con *Aggiornamenti automatici* (voce 0), *Tutte le app* (voce 1) e le categorie; sotto, `SELEZIONE RAPIDA` (Consigliati / CHRK. / Extra / Mouse fix / Aggiorna script) e il conteggio della scansione |
| `$listHost` (Dock=Fill) | `$listHead` (titolo sezione, `n selezionati`, `Pulisci selezione`), `$flow` (le voci con l'intestazione di ogni categoria) e `$panelUpdates` (la sezione "Aggiornamenti automatici") |
| `$detail` (Dock=Right) | descrizione della voce sotto il mouse: nome, id, publisher, categoria, `consigliata` |
| `$bottom` (Dock=Bottom) | `$progress` (visibile solo durante un lavoro), `$lblStatus`, `$log` (RichTextBox) |

L'ordine con cui i pannelli entrano in `$form.Controls` decide il docking: prima `$listHost`
(Fill), poi `$detail`, `$rail`, `$bottom`, `$top`.

La sezione "Aggiornamenti automatici" **non** passa da `APPLICA SELEZIONATI`: ha il suo
`Salva impostazioni` (crea/aggiorna/rimuove il task) e `Esegui adesso`.

### Trappole della GUI gia' incontrate (non ripeterle)

- **`$rows` e `$script:Rows` sono la stessa variabile.** PowerShell non distingue maiuscole e
  minuscole: serve un nome diverso per la lista locale della categoria (es. `$catRows`),
  altrimenti ogni voce viene aggiunta due volte e `$script:Rows` contiene solo l'ultima
  categoria.
- **`DrawString` con un `Rectangle` sceglie l'overload con `PointF`** e lancia
  `Impossibile convertire l'argomento "point"`: passare sempre un `RectangleF`.
- **Mostrare/nascondere voci costa.** Con 200+ `CheckBox` dentro un `FlowLayoutPanel` con
  `AutoScroll` ogni cambiamento di `Visible` fa ricalcolare tutto il layout: senza
  `SuspendLayout()` / `ResumeLayout($true)` intorno al filtro la UI si blocca per decine di
  secondi (finestra bianca, lista vuota).
- **`GroupBox` con `AutoSize` dentro un `FlowLayoutPanel`** non si dimensiona in modo
  affidabile: e' il motivo per cui le voci sono `CheckBox` con larghezza impostata dal
  gestore `Resize` di `$flow`, e le categorie sono `Label` intestazione.
- Il filtro della ricerca ignora la categoria selezionata (cerca sempre in tutte) e
  `-Preset` viene applicato alla fine della scansione: un `-Preset none` non deve azzerare le
  scelte fatte a mano mentre la scansione gira.

## Attivita' comuni

### Aggiungere una categoria

1. Aggiungi la regola in `Get-Cat` di `build/build.ps1` (ordine = priorita').
2. Spostala in `$catOrder` (stessa funzione) nella posizione desiderata: quell'ordine decide
   sia l'elenco delle voci sia l'ordine nel rail della GUI.
3. Ricompila e controlla che il conteggio abbia senso.

### Aggiungere un'app alle consigliate (base)

Aggiungi l'id winget in `build/ez.json`: e' un array di id, una riga ciascuno, ed e' anche
l'elenco della guida `x.chrk.tk/ez`. Un'app puo' stare sia qui sia nella lista dell'autore:
`ez` e' un flag in piu' (`ez = '1'`), non un preset alternativo.

### Togliere un'app dal catalogo

Aggiungi l'id in `build/exclude.json`: resta fuori da tutte le fonti, anche se winstall/WinUtil
lo conoscono. Il build stampa quante voci ha escluso.

### Aggiungere un pacchetto al preset Extra

Aggiungi l'id winget in `build/extras.json`. Se winstall/WinUtil non lo conoscono, aggiungi
nome e descrizione in `build/names.json`.

### Aggiornare la lista dell'autore

Su un PC con le app installate:

```powershell
.\tools\export-winget.ps1
```

Poi ricompila. Lo script aggiorna `build/catalog-mine.json` e produce una lista di app non
reinstallabili via winget (`apps-manuali.md`).

### Aggiungere un tweak o un wizard

Sono righe letterali in `build/tweaks.inc` (come i fix mouse): una entry per riga, senza
virgola finale.

```powershell
# tweak: uno o piu' valori di registro
@{ id = 'tweak-x'; name = '...'; cat = 'Tweaks di Windows'; preset = ''; guida = '1'; kind = 'tweak';
   ops = @( @{ path = 'HKCU:\Software\...'; name = 'Valore'; type = 'DWord'; value = 0 },
            @{ path = 'HKCU:\Software\...'; name = 'Altro'; remove = 1 } ); desc = '...' }

# wizard: comando aperto in una finestra PowerShell elevata
@{ id = 'wizard-x'; name = '...'; cat = 'Wizard e script'; preset = ''; guida = '1'; kind = 'cmd';
   cmd = 'irm https://esempio | iex'; desc = '...' }
```

`remove = 1` cancella il valore (riporta il default di Windows), utile per la voce
"Ripristina". Ricordati la trappola della hashtable (`$op.remove` = metodo `Remove()`):
leggere i campi con `Get-OpField`.

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
      `[void][System.Management.Automation.Language.Parser]::ParseFile('dist\CHRK-Installer.ps1',[ref]$null,[ref]$e)`
- [ ] Nessun `.ps1` contiene caratteri non-ASCII.
- [ ] `.\dist\CHRK-Installer.ps1 -Console -Preset mouse -DryRun` mostra il fix della scala giusta.
- [ ] `.\dist\CHRK-Installer.ps1 -ShowVersion` stampa la versione di `VERSION`.
- [ ] La GUI si apre senza errori (anche solo per pochi secondi): `.\tools\shots.ps1`
      la avvia, salva uno screenshot e la chiude - utile per controllare rail, categorie e
      la sezione "Aggiornamenti automatici" senza guardare lo schermo.
- [ ] `dist/CHRK-Installer.ps1` e' stato ricompilato (non committare `build/` senza `dist/`).

## Cose da NON fare

- Non committare `dist/*.bak`, log (`chrk-update.log`) o credenziali.
- **Mai** committare token Cloudflare, GitHub o altro: `.gitignore` copre `.cf-token`,
  `*.token`, `.env`.
- Non introdurre dipendenze esterne a runtime: lo script deve funzionare con PowerShell 5.1
  e `winget` e basta.
- Non usare `-RunLevel Highest` come default per il task pianificato: winget non vede i
  pacchetti installati per-utente quando e' elevato.
- Non rimuovere il blocco di auto-install in memoria: e' cio' che permette il comando unico
  `irm s.chrk.tk | iex`.
