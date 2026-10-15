# Fix mouse (MarkC)

## Provenienza

I valori in `build/mousefixes.inc` sono estratti dai `.reg` di
**MarkC Windows 10+8.x+7+Vista+XP MouseFix Builder 2.6**
(<http://donewmouseaccel.blogspot.com/2010/04/markc-mouse-acceleration-fix-builder.html>).

Sono **dati di registro**, non codice dell'autore: le curve `SmoothMouseXCurve` /
`SmoothMouseYCurve` e le soglie di accelerazione. Nella repo non c'e' lo zip originale
(terze parti): c'e' solo il risultato dell'estrazione, cosi' il build e' riproducibile
senza ridistribuire il pacchetto altrui.

## Cosa applica lo script

Per ogni voce `kind = 'mouse'`:

| Campo | Chiave di registro |
|---|---|
| `x` | `HKCU\Control Panel\Mouse` → `SmoothMouseXCurve` (binario) |
| `y` | `HKCU\Control Panel\Mouse` → `SmoothMouseYCurve` (binario) |
| `sens` | `HKCU\Control Panel\Mouse` → `MouseSensitivity` (stringa) |
| `speed` | `HKU\.DEFAULT\Control Panel\Mouse` → `MouseSpeed` |
| `t1`, `t2` | `HKU\.DEFAULT\Control Panel\Mouse` → `MouseThreshold1` / `MouseThreshold2` |

I campi vuoti vengono saltati: cosi' "Ripristina default" tocca solo le curve e
"benvenuto/login" tocca solo il profilo `.DEFAULT`.

## Voci incluse

- **Mouse Fix 1:1 @6/11** per ItemsSize 100, 125, 150, 175, 200, 225, 250, 300, 350%
- **Emula W95/98** (soglie 2/7, 3/7, 4/7) — solo ItemsSize 100%
- **Emula Windows 2000 (Low)** — solo ItemsSize 100%
- **Disabilita accelerazione su benvenuto/login** (profilo `.DEFAULT`)
- **Ripristina curva predefinita di Windows**

La scala DPI viene rilevata da `HKCU\Control Panel\Desktop\WindowMetrics\AppliedDPI`
(ripiego: `LogPixels`), quindi `-Preset mouse` seleziona automaticamente la variante giusta.

## Avvertenze (importanti)

- Le varianti a **due soglie** di W95/98 (5/7, 6/7, 7/7) e W2K Medium/High sono **escluse**:
  l'autore documenta che su **Windows 10/11 x64 causano BSOD**. Non aggiungerle.
- Dopo l'applicazione serve **logoff/login** (o riavvio) per l'effetto completo.
- Un fix di registro agisce solo quando in Windows *Enhance pointer precision* e' attiva
  (o quando un gioco la forza) e il gioco non usa Raw Input.
- La sensibilità 6/11 corrisponde a `MouseSensitivity = 10`.

## Rigenerare `mousefixes.inc`

Da una macchina Windows con lo zip MarkC:

```powershell
# 1) estrai lo zip
Expand-Archive "$env:USERPROFILE\Downloads\MarkC_*_MouseFix_Builder_2.6.zip" -DestinationPath "$env:TEMP\markc" -Force

# 2) rigenera le righe (script usato per la prima generazione)
#    legge i .reg in "$env:TEMP\markc\Windows 10 Fixes" e scrive build\mousefixes.inc
.\build\gen-mousefixes.ps1
```

`gen-mousefixes.ps1` non e' incluso nella repo per non dipendere dallo zip: se serve,
si ricostruisce seguendo la tabella qui sopra (chiavi e sezioni sono elencate).
`build/mousefixes.inc` e' la fonte di verita' per il build.
