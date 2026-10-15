<#
.SYNOPSIS
    Rigenera build/mousefixes.inc dai .reg del MarkC Mouse Fix Builder.

.DESCRIPTION
    Serve lo zip MarkC estratto in $env:TEMP\markc (vedi docs/mousefixes.md).
    Estrae curve e soglie dai .reg della cartella "Windows 10 Fixes" e produce le righe
    letterali dei fix mouse usate da build.ps1.

    Lo zip non e' nella repo (terze parti): questo script serve solo per rigenerare i dati.

.EXAMPLE
    Expand-Archive "$env:USERPROFILE\Downloads\MarkC_*_MouseFix_Builder_2.6.zip" -DestinationPath "$env:TEMP\markc" -Force
    .\build\gen-mousefixes.ps1
#>
[CmdletBinding()]
param(
    [string]$MarkcDir = "$env:TEMP\markc",
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$buildDir = $PSScriptRoot
if (-not $OutFile) { $OutFile = Join-Path $buildDir 'mousefixes.inc' }
$enc = [System.Text.UTF8Encoding]::new($false)
$w10 = Join-Path $MarkcDir 'Windows 10 Fixes'
if (-not (Test-Path $w10)) { throw "Cartella non trovata: $w10 (estrai prima lo zip MarkC)" }

function Parse-Reg([string]$path) {
    $lines = Get-Content -LiteralPath $path
    $out = @{}; $cur = $null
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $l = $lines[$i].Trim()
        if ($l -match '^\[(.+)\]$') { $cur = $Matches[1]; if (-not $out.ContainsKey($cur)) { $out[$cur] = @{} }; continue }
        if ($null -eq $cur) { continue }
        if ($l -match '^"([^"]+)"=(.*)$') {
            $name = $Matches[1]; $val = $Matches[2]
            if ($val -match '^hex:') {
                $hex = $val.Substring(4)
                while ($hex.TrimEnd().EndsWith('\')) {
                    $i++
                    if ($i -ge $lines.Count) { break }
                    $hex = $hex.TrimEnd().TrimEnd('\') + ' ' + $lines[$i].Trim()
                }
                $bytes = (($hex -replace '[\s\\]', '') -split ',' | Where-Object { $_ -ne '' })
                $out[$cur][$name] = (($bytes | ForEach-Object { $_.ToUpper() }) -join ',')
            }
            else { $out[$cur][$name] = $val.Trim('"') }
        }
    }
    return $out
}
function Reg-Get($parsed, [string]$section, [string]$name) {
    if ($parsed.ContainsKey($section) -and $parsed[$section].ContainsKey($name)) { return $parsed[$section][$name] }
    return ''
}

$HKCU = 'HKEY_CURRENT_USER\Control Panel\Mouse'
$DEF  = 'HKEY_USERS\.DEFAULT\Control Panel\Mouse'
$items = [System.Collections.Generic.List[object]]::new()

function Add-Item($id, $name, $scale, $sens, $x, $y, $speed, $t1, $t2, $note) {
    $items.Add([pscustomobject]@{
        id = $id; name = $name; cat = 'Mouse'; scale = $scale
        sens = $sens; x = $x; y = $y; speed = $speed; t1 = $t1; t2 = $t2; desc = $note
    })
}

# 1:1 @6/11 per ogni ItemsSize
foreach ($f in (Get-ChildItem -LiteralPath $w10 -Filter 'Windows_10+8.x_MouseFix_ItemsSize=*_Scale=1-to-1_@6-of-11.reg' | Sort-Object Name)) {
    if ($f.Name -notmatch 'ItemsSize=(\d+)%') { continue }
    $scale = $Matches[1]
    $p = Parse-Reg $f.FullName
    $note = "Curva MarkC 1:1, sensibilita 6/11. Vale per ItemsSize $scale%. Serve 'Enhance pointer precision' attiva per i giochi che la forzano."
    Add-Item "mouse-1to1-$scale" "Mouse Fix 1:1 @6/11 - ItemsSize $scale%" $scale `
        (Reg-Get $p $HKCU 'MouseSensitivity') (Reg-Get $p $HKCU 'SmoothMouseXCurve') (Reg-Get $p $HKCU 'SmoothMouseYCurve') `
        (Reg-Get $p $DEF 'MouseSpeed') (Reg-Get $p $DEF 'MouseThreshold1') (Reg-Get $p $DEF 'MouseThreshold2') $note
}

# emulazioni (solo ItemsSize 100%, varianti a 1 soglia: quelle a 2 soglie sono escluse per BSOD)
$emul = @(
    @{ f = 'Emulate Windows 95+98 Acceleration\Windows_10_MouseFix_Scale=W95+98_2of7_x1_x2@10+_ItemsSize=100%_@6-of-11.reg'; id = 'mouse-emul-w9598-2of7'; n = 'Emula W95/98 (2/7 - soglia alta)' }
    @{ f = 'Emulate Windows 95+98 Acceleration\Windows_10_MouseFix_Scale=W95+98_3of7_x1_x2@7+_ItemsSize=100%_@6-of-11.reg';  id = 'mouse-emul-w9598-3of7'; n = 'Emula W95/98 (3/7 - soglia media)' }
    @{ f = 'Emulate Windows 95+98 Acceleration\Windows_10_MouseFix_Scale=W95+98_4of7_x1_x2@4+_ItemsSize=100%_@6-of-11.reg';  id = 'mouse-emul-w9598-4of7'; n = 'Emula W95/98 (4/7 - soglia bassa)' }
    @{ f = 'Emulate Windows 2000 Acceleration\Windows_10_MouseFix_Scale=W2K_Low_x1_x2@7+_ItemsSize=100%_@6-of-11.reg';      id = 'mouse-emul-w2k-low';    n = 'Emula Windows 2000 (Low)' }
)
foreach ($e in $emul) {
    $p = Parse-Reg (Join-Path $w10 $e.f)
    Add-Item $e.id $e.n '100' `
        (Reg-Get $p $HKCU 'MouseSensitivity') (Reg-Get $p $HKCU 'SmoothMouseXCurve') (Reg-Get $p $HKCU 'SmoothMouseYCurve') `
        (Reg-Get $p $DEF 'MouseSpeed') (Reg-Get $p $DEF 'MouseThreshold1') (Reg-Get $p $DEF 'MouseThreshold2') `
        'Emulazione storica dell accelerazione. Solo ItemsSize 100%. Le varianti a 2 soglie sono ESCLUSE (BSOD su Windows 10/11 x64).'
}

# welcome/login
$p = Parse-Reg (Join-Path $MarkcDir 'Disable_WelcomeScreen+Login_Accel.reg')
Add-Item 'mouse-welcome' 'Disabilita accelerazione su schermata di benvenuto/login' '' '' '' '' `
    (Reg-Get $p $DEF 'MouseSpeed') (Reg-Get $p $DEF 'MouseThreshold1') (Reg-Get $p $DEF 'MouseThreshold2') `
    'Zero le soglie nel profilo .DEFAULT: vale per la schermata di login e il primo avvio.'

# ripristino default
$p = Parse-Reg (Join-Path $MarkcDir 'Windows_10+8.x_Default.reg')
Add-Item 'mouse-default' 'Ripristina curva mouse predefinita di Windows' '' '' `
    (Reg-Get $p $HKCU 'SmoothMouseXCurve') (Reg-Get $p $HKCU 'SmoothMouseYCurve') '' '' '' `
    'Rimette le curve originali di Windows 10/11 (annulla il mouse fix).'

$lines = foreach ($it in $items) {
    $n = $it.name.Replace("'", "''"); $d = $it.desc.Replace("'", "''")
    ("    @{{ id = '{0}'; name = '{1}'; cat = '{2}'; preset = ''; kind = 'mouse'; scale = '{3}'; sens = '{4}'; x = '{5}'; y = '{6}'; speed = '{7}'; t1 = '{8}'; t2 = '{9}'; desc = '{10}' }}" -f `
        $it.id, $n, $it.cat, $it.scale, $it.sens, $it.x, $it.y, $it.speed, $it.t1, $it.t2, $d)
}
[System.IO.File]::WriteAllLines($OutFile, $lines, $enc)
Write-Host ("Scritti {0} fix mouse in {1}" -f $items.Count, $OutFile) -ForegroundColor Green
