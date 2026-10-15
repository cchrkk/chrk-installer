# ============================================================================
# LEGACY: serve solo se vuoi ricreare il vecchio s.chrk.tk (Redirect Rule -> raw).
# Il comando pubblicato adesso e' irm ez.chrk.tk | iex, servito dal Worker in worker/
# (un host, due cose: guida per il browser, script per irm). Vedi docs/publishing.md.
# ============================================================================

<#
.SYNOPSIS
    Configura s.chrk.tk su Cloudflare: record DNS + Redirect Rule verso GitHub raw.

.DESCRIPTION
    Legge il token da -TokenFile o dalla variabile d'ambiente CF_API_TOKEN.
    Non stampa mai il token. Idempotente: aggiorna se esiste, crea se manca.

.EXAMPLE
    $env:CF_API_TOKEN = '...'
    .\tools\setup-cloudflare.ps1
    .\tools\setup-cloudflare.ps1 -Repo chrk-installer -Remove
#>
[CmdletBinding()]
param(
    [string]$Zone = 'chrk.tk',
    [string]$Hostname = 's',
    [string]$RepoOwner = 'cchrkk',
    [string]$Repo = 'chrk-installer',
    [string]$Branch = 'main',
    [string]$Path = 'dist/CHRK-Installer.ps1',
    [string]$TokenFile,
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'
if (-not $TokenFile) {
    $candidate = Join-Path ([Environment]::GetFolderPath('Desktop')) '.cf-token'
    if (Test-Path $candidate) { $TokenFile = $candidate }
}
$token = if ($TokenFile -and (Test-Path $TokenFile)) { (Get-Content $TokenFile -Raw).Trim() } else { $env:CF_API_TOKEN }
if (-not $token) { throw "Token mancante: usa -TokenFile oppure la variabile CF_API_TOKEN." }

$api  = 'https://api.cloudflare.com/client/v4'
$head = @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' }
function Invoke-CF([string]$Method, [string]$Uri, $Body) {
    $p = @{ Method = $Method; Uri = "$api$Uri"; Headers = $head }
    if ($Body) { $p.Body = ($Body | ConvertTo-Json -Depth 12) }
    try { return Invoke-RestMethod @p }
    catch {
        $detail = ''
        try { $detail = $_.ErrorDetails.Message } catch { }
        throw ("Cloudflare API {0} {1} -> {2} {3}" -f $Method, $Uri, $_.Exception.Message, $detail)
    }
}

$fqdn = "$Hostname.$Zone"
$z = Invoke-CF GET "/zones?name=$Zone"
if (-not $z.result.Count) { throw "Zona $Zone non trovata (il token ha accesso alla zona?)" }
$zid = $z.result[0].id
Write-Host ("Zona {0} ({1})" -f $Zone, $zid) -ForegroundColor Cyan

$ruleDesc = "chrk-installer -> GitHub raw"
$phase = 'http_request_dynamic_redirect'

if ($Remove) {
    # rimuovi le regole di questo host
    try {
        $rs = Invoke-CF GET "/zones/$zid/rulesets/phases/$phase/entrypoint"
        $keep = @($rs.result.rules | Where-Object { $_.description -ne $ruleDesc -and ([string]$_.expression) -notlike "*$fqdn*" })
        Invoke-CF PUT "/zones/$zid/rulesets/phases/$phase/entrypoint" @{ rules = $keep } | Out-Null
        Write-Host "Regola di redirect rimossa." -ForegroundColor Yellow
    } catch { Write-Host "Nessuna regola da rimuovere." -ForegroundColor DarkGray }
    $d = Invoke-CF GET "/zones/$zid/dns_records?name=$fqdn"
    foreach ($r in @($d.result)) { Invoke-CF DELETE "/zones/$zid/dns_records/$($r.id)" | Out-Null }
    Write-Host "Record DNS $fqdn rimosso." -ForegroundColor Yellow
    return
}

$target = "https://raw.githubusercontent.com/$RepoOwner/$Repo/$Branch/$Path"

# --- DNS ---
$d = Invoke-CF GET "/zones/$zid/dns_records?name=$fqdn"
$rec = @{ type = 'CNAME'; name = $Hostname; content = "$RepoOwner.github.io"; proxied = $true; ttl = 1; comment = 'chrk-installer' }
if ($d.result.Count) {
    Invoke-CF PUT "/zones/$zid/dns_records/$($d.result[0].id)" $rec | Out-Null
    Write-Host "DNS aggiornato: $fqdn -> $RepoOwner.github.io (proxied)" -ForegroundColor Green
} else {
    Invoke-CF POST "/zones/$zid/dns_records" $rec | Out-Null
    Write-Host "DNS creato: $fqdn -> $RepoOwner.github.io (proxied)" -ForegroundColor Green
}

# --- Redirect rule ---
$newRule = @{
    action      = 'redirect'
    description = $ruleDesc
    enabled     = $true
    expression  = ('(http.host eq "{0}")' -f $fqdn)
    action_parameters = @{
        from_value = @{
            status_code           = 302
            preserve_query_string = $false
            target_url            = @{ value = $target }
        }
    }
}
$existing = @()
try {
    $existing = @((Invoke-CF GET "/zones/$zid/rulesets/phases/$phase/entrypoint").result.rules |
        Where-Object { $_ -and $_.action -and $_.expression })
} catch { $existing = @() }
# rimanda solo i campi scrivibili (l'API rifiuta quelli read-only).
# Scarta sia la regola con la nostra descrizione sia qualunque residuo che punti a questo
# hostname: due regole sullo stesso host si annullano a vicenda (vince la prima).
$keep = @()
foreach ($r in $existing) {
    if ($r.description -eq $ruleDesc) { continue }
    if (([string]$r.expression) -like "*$fqdn*") { continue }
    $o = [ordered]@{}
    foreach ($k in @('action', 'description', 'enabled', 'expression', 'action_parameters', 'ref')) {
        if ($r.PSObject.Properties[$k]) { $o[$k] = $r.$k }
    }
    $keep += $o
}
$rules = @($keep) + $newRule
Invoke-CF PUT "/zones/$zid/rulesets/phases/$phase/entrypoint" @{ rules = $rules } | Out-Null
Write-Host ("Regola redirect: {0} -> {1}" -f $fqdn, $target) -ForegroundColor Green

Write-Host ""
Write-Host "Prova:" -ForegroundColor Cyan
Write-Host "  irm $fqdn | iex"
