<#
.SYNOPSIS
    Rigenera build/catalog-mine.json (preset "CHRK.") da questo PC.

.DESCRIPTION
    Esegue "winget export", lo copia in build/catalog-mine.json e produce
    build/apps-manuali.md con cio' che winget NON puo' reinstallare
    (programmi con installer proprio, giochi Steam, app Store).

.EXAMPLE
    .\tools\export-winget.ps1
    .\tools\export-winget.ps1 -SkipManualList
#>
[CmdletBinding()]
param(
    [string]$OutJson,
    [switch]$SkipManualList
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if (-not $OutJson) { $OutJson = Join-Path $repo 'build\catalog-mine.json' }

$tmp = Join-Path $env:TEMP 'winget-export.json'
Write-Host "winget export..." -ForegroundColor Cyan
winget export --output $tmp --accept-source-agreements --disable-interactivity 2>&1 |
    Where-Object { $_ -notmatch 'not available from any source' } | Out-Null
if (-not (Test-Path $tmp)) { throw "winget export non ha prodotto il file" }

Copy-Item $tmp $OutJson -Force
$exp = Get-Content $OutJson -Raw | ConvertFrom-Json
$ids = foreach ($s in $exp.Sources) { foreach ($p in $s.Packages) { $p.PackageIdentifier } }
Write-Host ("OK: {0} pacchetti -> {1}" -f @($ids).Count, $OutJson) -ForegroundColor Green

if ($SkipManualList) { return }

# lista di cio' che winget non copre (utile per un format)
$listTxt = Join-Path $env:TEMP 'winget-list.txt'
winget list --accept-source-agreements --disable-interactivity 2>&1 | Out-String | Set-Content $listTxt -Encoding UTF8

$manual = @(); $steam = @(); $store = @()
foreach ($line in (Get-Content $listTxt)) {
    if ($line -match '^\s*$' -or $line -match '^-{5,}' -or $line -match '^\s*Name\s+Id\s') { continue }
    $parts = $line -split '\s{2,}'
    if ($parts.Count -lt 2) { continue }
    $name = $parts[0].Trim(); $id = $parts[1].Trim(); $src = $parts[-1].Trim()
    if ($src -eq 'winget' -or $src -eq 'msstore') { continue }
    if ($id -like '*Steam App*') { $steam += [pscustomobject]@{ Name = $name; AppId = ($id -split 'Steam App ')[-1].Trim() }; continue }
    if ($id -like 'MSIX*') { $store += $name; continue }
    if ($id -like 'ARP*')  { $manual += [pscustomobject]@{ Name = $name; Id = $id } }
}

$md = Join-Path $repo 'build\apps-manuali.md'
$out = @('# App NON reinstallabili automaticamente con winget', '')
$out += "## Programmi con installer proprio ($($manual.Count))", ''
$out += ($manual | Sort-Object Name | ForEach-Object { "- $($_.Name)  (``$($_.Id)``)" })
$out += '', "## Giochi Steam ($($steam.Count))", ''
$out += ($steam | Sort-Object Name | ForEach-Object { "- $($_.Name)  (appid $($_.AppId))" })
$out += '', "## App Microsoft Store / componenti di sistema ($($store.Count))", ''
$out += ($store | Sort-Object | ForEach-Object { "- $_" })
[System.IO.File]::WriteAllText($md, ($out -join "`r`n"), [System.Text.UTF8Encoding]::new($false))
Write-Host ("Lista app manuali -> {0}" -f $md) -ForegroundColor Green
