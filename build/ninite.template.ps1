<#
    Ninite-Custom.ps1  -  installer stile Ninite con winget  +  fix mouse MarkC
    Generato per FISSO-ALI il 2026-10-15.

    PUBBLICAZIONE / INSTALL DA URL
      Il file e' servito su un URL corto (Cloudflare -> GitHub), quindi basta:
        irm https://s.chrk.tk | iex
      Lo script, se eseguito in memoria, si copia da solo in
        %LOCALAPPDATA%\Ninite-Custom\Ninite-Custom.ps1
      e si riavvia da li' (serve per cronjob e auto-aggiornamento).
      Il file e' AUTOCONTENUTO: catalogo e logo sono embeddati, unica dipendenza winget.

    FUNZIONI
      - lista selezionabile di pacchetti winget (i tuoi + extra) e di fix mouse
      - rileva cio' che e' GIA' installato/applicato e lo salta
      - avanzamento chiaro: pacchetto corrente, n/total, %, ETA, esito per pacchetto
      - "Aggiorna tutto" (winget upgrade --all)
      - pianifica un aggiornamento automatico (cronjob / Task Scheduler)
      - modalita' console per script e per il cronjob

    USO
        .\Ninite-Custom.ps1                      # GUI
        .\Ninite-Custom.ps1 -Preset mine         # GUI coi tuoi pacchetti preselezionati
        .\Ninite-Custom.ps1 -Preset mouse        # GUI coi fix mouse consigliati
        .\Ninite-Custom.ps1 -Console             # elenco a console
        .\Ninite-Custom.ps1 -Console -Preset extra -DryRun
        .\Ninite-Custom.ps1 -Select 'Git.Git','mouse-1to1-100' -Console
        .\Ninite-Custom.ps1 -UpgradeAll                       # aggiorna tutto (usato dal cronjob)
        .\Ninite-Custom.ps1 -InstallCron -EveryDays 7 -CronTime 03:00
        .\Ninite-Custom.ps1 -RemoveCron

    Logica install ripresa da winutil.ps1 (exit code, msstore, --silent).
    Fix mouse: valori estratti da MarkC Mouse Fix Builder 2.6.
#>
[CmdletBinding()]
param(
    [string[]]$Select,
    [ValidateSet('mine', 'extra', 'mouse', 'all', 'none')]
    [string]$Preset = 'none',
    [switch]$SkipInstalled,
    [switch]$Console,
    [switch]$DryRun,
    [switch]$UpgradeAll,
    [switch]$ForceReinstall,
    [switch]$InstallCron,
    [int]$EveryDays = 7,
    [string]$CronTime = '03:00',
    [switch]$CronElevated,
    [switch]$RemoveCron,
    [switch]$ShowVersion,
    [switch]$SelfUpdate,
    [switch]$NoSelfInstall,
    [string]$LogFile
)

$ErrorActionPreference = 'Stop'
$TaskName = 'Ninite-Custom Update'
$script:Version   = '__VERSION__'
$script:UpdateUrl = '__UPDATE_URL__'

# ==== UN SOLO FILE: se eseguito in memoria (irm ... | iex) si installa da solo =
if (-not $PSCommandPath -and -not $NoSelfInstall) {
    $dirDst = Join-Path $env:LOCALAPPDATA 'Ninite-Custom'
    $dst    = Join-Path $dirDst 'Ninite-Custom.ps1'
    Write-Host ("Ninite-Custom v{0} - esecuzione in memoria (irm | iex)" -f $script:Version) -ForegroundColor Cyan
    Write-Host ("Installo la copia locale in {0}" -f $dst) -ForegroundColor Gray
    Write-Host "Serve per: cronjob, auto-aggiornamento e per non riscaricare tutto ogni volta." -ForegroundColor Gray
    $ok = $false
    try {
        New-Item -ItemType Directory -Force -Path $dirDst | Out-Null
        Invoke-WebRequest -Uri $script:UpdateUrl -OutFile $dst -UseBasicParsing -ErrorAction Stop
        $ok = (Test-Path $dst) -and ((Get-Item $dst).Length -gt 1000)
    } catch {
        Write-Host ("Download non riuscito da {0}: {1}" -f $script:UpdateUrl, $_.Exception.Message) -ForegroundColor Yellow
    }
    if ($ok) {
        $fwd = @{}
        foreach ($k in $PSBoundParameters.Keys) { if ($k -ne 'NoSelfInstall') { $fwd[$k] = $PSBoundParameters[$k] } }
        Write-Host "Avvio dalla copia locale (da qui in poi hai un solo file su disco)..." -ForegroundColor Green
        & $dst @fwd
        return
    }
    Write-Host "Continuo con l'istanza in memoria: la GUI funziona, cronjob/auto-update no." -ForegroundColor Yellow
}


# ==== catalogo ==============================================================
$Packages = @(
__PACKAGES__
)
$Packages = @($Packages | ForEach-Object { [pscustomobject]$_ })
$LogoB64  = '__LOGO_B64__'

# ==== winget helpers (stessa logica di WinUtil) =============================
$script:AdminContextProhibited = -1978335107
$script:NothingToDo = @{ -1978335135 = 'gia installato'; -1978335189 = 'nessun aggiornamento applicabile' }
$script:RebootCodes = @{
    3010 = 'installato, riavvio consigliato'; 1641 = 'installato, il setup ha avviato il riavvio'
    -1978334967 = 'installato, riavvio consigliato'; -1978334965 = 'installato, il setup ha avviato il riavvio'
}

function Convert-HexToBytes([string]$hex) {
    return [byte[]](($hex -split ',' | Where-Object { $_ -ne '' }) | ForEach-Object { [Convert]::ToByte($_.Trim(), 16) })
}
function Apply-MouseFix($pkg) {
    $base = 'HKCU:\Control Panel\Mouse'
    $def  = 'Registry::HKEY_USERS\.DEFAULT\Control Panel\Mouse'
    if ($pkg.x)    { Set-ItemProperty -Path $base -Name SmoothMouseXCurve -Type Binary -Value (Convert-HexToBytes $pkg.x) }
    if ($pkg.y)    { Set-ItemProperty -Path $base -Name SmoothMouseYCurve -Type Binary -Value (Convert-HexToBytes $pkg.y) }
    if ($pkg.sens) { Set-ItemProperty -Path $base -Name MouseSensitivity   -Type String -Value $pkg.sens }
    if ($pkg.speed) { Set-ItemProperty -Path $def -Name MouseSpeed      -Type String -Value $pkg.speed }
    if ($pkg.t1)    { Set-ItemProperty -Path $def -Name MouseThreshold1 -Type String -Value $pkg.t1 }
    if ($pkg.t2)    { Set-ItemProperty -Path $def -Name MouseThreshold2 -Type String -Value $pkg.t2 }
}
function Get-CurrentCurveHex([string]$name) {
    try {
        $v = (Get-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name $name -ErrorAction Stop).$name
        return (($v | ForEach-Object { ([int]$_).ToString('X2') }) -join ',')
    } catch { return '' }
}
function Get-CurrentScale {
    $dpi = 0
    try { $dpi = [int](Get-ItemProperty 'HKCU:\Control Panel\Desktop\WindowMetrics' -Name AppliedDPI -ErrorAction Stop).AppliedDPI } catch {}
    if (-not $dpi) { try { $dpi = [int](Get-ItemProperty 'HKCU:\Control Panel\Desktop' -Name LogPixels -ErrorAction Stop).LogPixels } catch {} }
    if (-not $dpi) { $dpi = 96 }
    $map = @{ 96='100'; 120='125'; 144='150'; 168='175'; 192='200'; 216='225'; 240='250'; 288='300'; 336='350' }
    if ($map.ContainsKey($dpi)) { return $map[$dpi] }
    return '100'
}

function Install-OnePackage {
    param([Parameter(Mandatory)][string]$Id, [string]$Source = 'winget', [switch]$Upgrade)
    $wargs = if ($Upgrade) {
        @('upgrade', '--id', $Id, '--exact', '--accept-package-agreements', '--accept-source-agreements', '--source', $Source, '--include-unknown', '--silent')
    } else {
        @('install', '--id', $Id, '--exact', '--accept-package-agreements', '--accept-source-agreements', '--source', $Source, '--silent')
    }
    $p = Start-Process -FilePath winget -ArgumentList $wargs -NoNewWindow -Wait -PassThru
    $c = $p.ExitCode
    if ($c -eq 0) { return @{ Outcome = 'OK'; Detail = if ($Upgrade) { 'aggiornato' } else { 'installato' } } }
    if ($script:RebootCodes.ContainsKey($c)) { return @{ Outcome = 'OK'; Detail = $script:RebootCodes[$c] } }
    if ($script:NothingToDo.ContainsKey($c)) { return @{ Outcome = 'SKIP'; Detail = $script:NothingToDo[$c] } }
    if ($c -eq $script:AdminContextProhibited) { return @{ Outcome = 'SKIP'; Detail = 'installato per l''utente: serve senza elevazione' } }
    return @{ Outcome = 'FAIL'; Detail = ('winget 0x{0:X8}' -f $c) }
}
function Get-InstalledIds {
    $txt = (winget list --accept-source-agreements --disable-interactivity 2>&1 | Out-String)
    $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($pkg in $Packages) {
        if ($pkg.kind -ne 'pkg') { continue }
        if ($txt -match ('(?<!\S)' + [regex]::Escape($pkg.id) + '(?!\S)')) { $null = $set.Add($pkg.id) }
    }
    return $set
}
function Get-Preset([string]$name) {
    switch ($name) {
        'mine'  { return @($Packages | Where-Object { $_.preset -eq 'mine' } | Select-Object -ExpandProperty id) }
        'extra' { return @($Packages | Where-Object { $_.preset -eq 'extra' } | Select-Object -ExpandProperty id) }
        'mouse' {
            $s = Get-CurrentScale
            return @($Packages | Where-Object {
                $_.kind -eq 'mouse' -and ($_.id -eq 'mouse-welcome' -or ($_.id -like 'mouse-1to1-*' -and $_.scale -eq $s))
            } | Select-Object -ExpandProperty id)
        }
        'all'   { return @($Packages | Select-Object -ExpandProperty id) }
        default { return @() }
    }
}

# ==== cronjob (Task Scheduler) + self-update ================================
function Test-Admin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
        IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Get-CronStatus {
    try { return Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop } catch { return $null }
}
function Install-Cron([int]$everyDays, [string]$at, [switch]$elevated) {
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) { throw "Percorso dello script non disponibile (esecuzione in memoria). Salva il file su disco e riprova." }
    if (-not (Test-Path $scriptPath)) { throw "File dello script non trovato: $scriptPath" }
    if ($elevated -and -not (Test-Admin)) { throw "Per un task elevato serve PowerShell come Amministratore. Riprova senza elevazione (consigliato per winget)." }

    $logPath = if ($LogFile) { $LogFile } else { Join-Path (Split-Path $scriptPath) 'ninite-update.log' }
    $arg = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -UpgradeAll -LogFile "{1}"' -f $scriptPath, $logPath
    $action  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
    $trigger = New-ScheduledTaskTrigger -Daily -At $at -DaysInterval ([Math]::Max(1, $everyDays))
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 3) -MultipleInstances IgnoreNew
    $userId = ("{0}\{1}" -f $env:USERDOMAIN, $env:USERNAME)

    # Non elevato: task nel contesto utente (evita il problema winget "per-utente" sotto elevazione).
    # Elevato: richiede admin. S4U (senza password) e' il primo tentativo, poi Interactive.
    $attempts = if ($elevated) {
        @(
            @{ LogonType = 'S4U';         RunLevel = 'Highest' }
            @{ LogonType = 'Interactive'; RunLevel = 'Highest' }
        )
    } else {
        @(
            @{ LogonType = 'Interactive'; RunLevel = 'Limited' }
            @{ LogonType = 'S4U';         RunLevel = 'Limited' }
        )
    }

    $lastError = $null
    foreach ($a in $attempts) {
        try {
            $principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType $a.LogonType -RunLevel $a.RunLevel
            Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal `
                -Description 'Aggiorna tutti i pacchetti winget (Ninite-Custom).' -Force -ErrorAction Stop | Out-Null
            $lastError = $null
            break
        } catch { $lastError = $_ }
    }
    if ($lastError) { throw ("Registrazione del task non riuscita: " + $lastError.Exception.Message) }
    if (-not (Get-CronStatus)) { throw "Il task non risulta registrato." }
    return ("Task '{0}' pianificato ogni {1} giorno/i alle {2} (elevazione: {3}). Log: {4}" -f `
        $TaskName, [Math]::Max(1, $everyDays), $at, $(if ($elevated) { 'si' } else { 'no' }), $logPath)
}
function Remove-Cron {
    if (-not (Get-CronStatus)) { return "Nessun task '$TaskName' da rimuovere." }
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
    return "Task '$TaskName' rimosso."
}
function Get-RemoteVersion {
    $txt = (Invoke-WebRequest -Uri $script:UpdateUrl -UseBasicParsing -ErrorAction Stop).Content
    if ($txt -match "(?m)\`$script:Version\s*=\s*'([^']+)'") { return $Matches[1] }
    return $null
}
function Update-Self {
    if (-not $PSCommandPath) { throw "Esecuzione in memoria: salva prima lo script su disco." }
    $remote = (Invoke-WebRequest -Uri $script:UpdateUrl -UseBasicParsing -ErrorAction Stop).Content
    if ($remote -notmatch 'Ninite-Custom') { throw "Il file scaricato non sembra Ninite-Custom." }
    $cur = [System.IO.File]::ReadAllText($PSCommandPath)
    if ($cur -eq $remote) { return "Gia aggiornato (v$($script:Version))." }
    $rv = if ($remote -match "(?m)\`$script:Version\s*=\s*'([^']+)'") { $Matches[1] } else { '?' }
    Copy-Item $PSCommandPath "$PSCommandPath.bak" -Force
    [System.IO.File]::WriteAllText($PSCommandPath, $remote, [System.Text.UTF8Encoding]::new($false))
    return "Aggiornato: v$($script:Version) -> v$rv (backup in $PSCommandPath.bak). Riavvia lo script."
}

# ==== branch CLI ============================================================
if ($ShowVersion) { Write-Host ("Ninite-Custom v{0}" -f $script:Version); return }
if ($SelfUpdate) {
    try { Write-Host (Update-Self) -ForegroundColor Green } catch { Write-Host ("Errore aggiornamento: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
    return
}
if ($RemoveCron) { Write-Host (Remove-Cron) -ForegroundColor Cyan; return }
if ($InstallCron) {
    try { Write-Host (Install-Cron -everyDays $EveryDays -at $CronTime -elevated:$CronElevated) -ForegroundColor Green }
    catch { Write-Host ("Errore cronjob: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }
    return
}

# ==== modalita' console =====================================================
if ($Console -or $UpgradeAll) {
    if ($LogFile) { try { Start-Transcript -Path $LogFile -Append | Out-Null } catch {} }
    if ($UpgradeAll) {
        Write-Host ("[{0}] Aggiornamento di tutti i pacchetti..." -f (Get-Date -Format 's')) -ForegroundColor Cyan
        if ($DryRun) { Write-Host 'winget upgrade --all' }
        else {
            $wa = @('upgrade', '--all', '--accept-package-agreements', '--accept-source-agreements', '--include-unknown', '--silent')
            $p = Start-Process -FilePath winget -ArgumentList $wa -NoNewWindow -Wait -PassThru
            Write-Host ("upgrade --all exit code: {0}" -f $p.ExitCode) -ForegroundColor Green
        }
        if ($LogFile) { try { Stop-Transcript | Out-Null } catch {} }
        return
    }

    $chosen = if ($Select) { $Select } elseif ($Preset -ne 'none') { Get-Preset $Preset } else { @() }
    if (-not $chosen.Count) {
        Write-Host 'Nessun pacchetto selezionato. Usa -Select oppure -Preset.' -ForegroundColor Yellow
        Write-Host ''
        $Packages | Group-Object cat | Sort-Object Name | ForEach-Object {
            Write-Host ("[" + $_.Name + "]  (" + $_.Count + ")") -ForegroundColor Cyan
            $_.Group | Sort-Object name | ForEach-Object { Write-Host ("   " + $_.id.PadRight(46) + $_.name) }
        }
        if ($LogFile) { try { Stop-Transcript | Out-Null } catch {} }
        return
    }
    $installed = Get-InstalledIds
    $ok = 0; $skip = 0; $fail = 0
    foreach ($id in $chosen) {
        $pkg = $Packages | Where-Object { $_.id -eq $id } | Select-Object -First 1
        if (-not $pkg) { continue }
        if ($pkg.kind -eq 'mouse') {
            if ($DryRun) { Write-Host ("DRY   {0,-40} fix mouse" -f $pkg.name) -ForegroundColor DarkGray; continue }
            Write-Host (".... {0}" -f $pkg.name) -ForegroundColor Gray -NoNewline
            try { Apply-MouseFix $pkg; Write-Host ("`rOK    {0,-40} registro aggiornato" -f $pkg.name) -ForegroundColor Green; $ok++ }
            catch { Write-Host ("`rFAIL  {0,-40} {1}" -f $pkg.name, $_.Exception.Message) -ForegroundColor Red; $fail++ }
            continue
        }
        if ($installed.Contains($id) -and -not $ForceReinstall) {
            Write-Host ("SKIP  {0,-40} gia installato" -f $pkg.name) -ForegroundColor DarkGray
            $skip++; continue
        }
        if ($DryRun) { Write-Host ("DRY   {0,-40} winget install --id {1} --source {2}" -f $pkg.name, $id, $pkg.src) -ForegroundColor DarkGray; continue }
        Write-Host (".... {0}" -f $pkg.name) -ForegroundColor Gray -NoNewline
        $r = Install-OnePackage -Id $id -Source $pkg.src
        $color = switch ($r.Outcome) { 'OK' { 'Green' } 'SKIP' { 'DarkGray' } default { 'Red' } }
        Write-Host ("`r{0,-5} {1,-40} {2}" -f $r.Outcome, $pkg.name, $r.Detail) -ForegroundColor $color
        if ($r.Outcome -eq 'OK') { $ok++ } elseif ($r.Outcome -eq 'SKIP') { $skip++ } else { $fail++ }
    }
    Write-Host ''
    Write-Host ("Risultato: {0} ok, {1} saltati, {2} falliti" -f $ok, $skip, $fail) -ForegroundColor Cyan
    if ($LogFile) { try { Stop-Transcript | Out-Null } catch {} }
    return
}

# ==== GUI ===================================================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$col = @{
    bg  = [System.Drawing.ColorTranslator]::FromHtml('#11131a')
    bg2 = [System.Drawing.ColorTranslator]::FromHtml('#171a23')
    bg3 = [System.Drawing.ColorTranslator]::FromHtml('#1e222e')
    fg  = [System.Drawing.ColorTranslator]::FromHtml('#e6e8ee')
    mut = [System.Drawing.ColorTranslator]::FromHtml('#9aa2b5')
    acc = [System.Drawing.ColorTranslator]::FromHtml('#4c9aff')
    ok  = [System.Drawing.ColorTranslator]::FromHtml('#3fb950')
    warn = [System.Drawing.ColorTranslator]::FromHtml('#d29922')
    err = [System.Drawing.ColorTranslator]::FromHtml('#f85149')
}
$font     = [System.Drawing.Font]::new('Segoe UI', 9, [System.Drawing.FontStyle]::Regular)
$fontBold = [System.Drawing.Font]::new('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
$fontMono = [System.Drawing.Font]::new('Consolas', 8.5, [System.Drawing.FontStyle]::Regular)

$form = [System.Windows.Forms.Form]::new()
$form.Text = 'Ninite Custom (winget) - CHRK.'
$form.Size = [System.Drawing.Size]::new(1140, 800)
$form.MinimumSize = [System.Drawing.Size]::new(980, 640)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $col.bg
$form.ForeColor = $col.fg
$form.Font = $font

# --- top: logo + controlli ---
$top = [System.Windows.Forms.Panel]::new()
$top.Dock = 'Top'; $top.Height = 104; $top.BackColor = $col.bg2
$form.Controls.Add($top)

try {
    $bytes = [Convert]::FromBase64String($LogoB64)
    $ms = [System.IO.MemoryStream]::new($bytes, $false)
    $logo = [System.Windows.Forms.PictureBox]::new()
    $logo.Image = [System.Drawing.Image]::FromStream($ms)
    $logo.SetBounds(14, 16, 200, 71); $logo.SizeMode = 'Zoom'; $logo.BackColor = $col.bg2
    $top.Controls.Add($logo)
} catch { }

$lblTitle = [System.Windows.Forms.Label]::new()
$lblTitle.Text = 'Seleziona cosa installare  -  i pacchetti gia presenti vengono saltati'
$lblTitle.SetBounds(228, 8, 450, 18); $lblTitle.ForeColor = $col.mut
$top.Controls.Add($lblTitle)

$lblVer = [System.Windows.Forms.Label]::new()
$lblVer.Text = ("v{0}  -  aggiorna script" -f $script:Version)
$lblVer.SetBounds(694, 8, 300, 18); $lblVer.ForeColor = $col.acc; $lblVer.Cursor = 'Hand'
$top.Controls.Add($lblVer)

$txtSearch = [System.Windows.Forms.TextBox]::new()
$txtSearch.SetBounds(228, 30, 220, 24); $txtSearch.BackColor = $col.bg3; $txtSearch.ForeColor = $col.fg; $txtSearch.BorderStyle = 'FixedSingle'
$top.Controls.Add($txtSearch)

$chkForce = [System.Windows.Forms.CheckBox]::new()
$chkForce.Text = 'reinstalla se presente'; $chkForce.SetBounds(454, 32, 150, 20); $chkForce.ForeColor = $col.mut
$top.Controls.Add($chkForce)

$chkOnly = [System.Windows.Forms.CheckBox]::new()
$chkOnly.Text = 'solo scelti'; $chkOnly.SetBounds(608, 32, 88, 20); $chkOnly.ForeColor = $col.mut
$top.Controls.Add($chkOnly)

function New-Btn($text, $x, $y, $w, [string]$kind = 'ghost') {
    $b = [System.Windows.Forms.Button]::new()
    $b.Text = $text; $b.SetBounds($x, $y, $w, 26); $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderColor = $col.bg3
    if ($kind -eq 'primary') { $b.BackColor = $col.acc; $b.ForeColor = [System.Drawing.Color]::White }
    else { $b.BackColor = $col.bg3; $b.ForeColor = $col.fg }
    return $b
}

$btnInstall = New-Btn 'APPLICA SELEZIONATI' 700 29 180 'primary'
$btnUpgrade = New-Btn 'Aggiorna tutto' 886 29 140
$top.Controls.Add($btnInstall); $top.Controls.Add($btnUpgrade)

$btnMine   = New-Btn 'CHRK.'      228 60 62
$btnExtra  = New-Btn 'Extra'      294 60 54
$btnMouse  = New-Btn 'Mouse fix'  352 60 76
$btnNone   = New-Btn 'Nessuno'    432 60 68
$btnCron   = New-Btn 'Aggiorna in automatico...' 700 60 180
$btnSelf   = New-Btn 'Aggiorna script' 886 60 140
foreach ($b in @($btnMine, $btnExtra, $btnMouse, $btnNone, $btnCron, $btnSelf)) { $top.Controls.Add($b) }

$tip = [System.Windows.Forms.ToolTip]::new()
$tip.AutoPopDelay = 20000; $tip.InitialDelay = 250; $tip.ReshowDelay = 80
$tip.SetToolTip($btnMine,  'Riseleziona i pacchetti che avevi su questo PC piu gli extra scelti.')
$tip.SetToolTip($btnExtra, 'Le app nuove scelte a mano (non ancora installate).')
$tip.SetToolTip($btnMouse, 'Mouse fix MarkC: toglie l accelerazione del puntatore. Rileva la tua scala DPI.')
$tip.SetToolTip($btnNone,  'Deseleziona tutto.')
$tip.SetToolTip($btnCron,  'Crea un aggiornamento automatico: un task di Windows che esegue winget upgrade ogni N giorni.')
$tip.SetToolTip($btnSelf,  'Riscarica questa ultima versione dello script da internet.')
$tip.SetToolTip($btnInstall, 'Installa i pacchetti e applica i fix mouse selezionati.')
$tip.SetToolTip($btnUpgrade, 'Aggiorna TUTTI i programmi installati (winget upgrade --all).')
$tip.SetToolTip($chkForce, 'Se spuntato, reinstalla anche cio che risulta gia presente.')
$tip.SetToolTip($chkOnly,  'Mostra solo le voci che hai selezionato.')

$lblScan = [System.Windows.Forms.Label]::new()
$lblScan.SetBounds(508, 64, 190, 18); $lblScan.ForeColor = $col.mut
$top.Controls.Add($lblScan)

# --- bottom: avanzamento + log ---
$bottom = [System.Windows.Forms.Panel]::new()
$bottom.Dock = 'Bottom'; $bottom.Height = 210; $bottom.BackColor = $col.bg2
$form.Controls.Add($bottom)

$progress = [System.Windows.Forms.ProgressBar]::new()
$progress.SetBounds(14, 12, 1096, 16); $progress.Style = 'Continuous'
$progress.Anchor = 'Top,Left,Right'
$bottom.Controls.Add($progress)

$lblStatus = [System.Windows.Forms.Label]::new()
$lblStatus.SetBounds(14, 32, 1096, 18); $lblStatus.ForeColor = $col.fg; $lblStatus.Font = $fontBold
$lblStatus.Anchor = 'Top,Left,Right'
$bottom.Controls.Add($lblStatus)

$log = [System.Windows.Forms.RichTextBox]::new()
$log.SetBounds(14, 54, 1096, 148); $log.ReadOnly = $true; $log.ScrollBars = 'Vertical'; $log.WordWrap = $false
$log.BackColor = [System.Drawing.ColorTranslator]::FromHtml('#0d0f15'); $log.ForeColor = $col.fg; $log.Font = $fontMono
$log.Anchor = 'Top,Left,Right,Bottom'
$bottom.Controls.Add($log)

# --- pannello descrizione (appare passando il mouse) ---
$detail = [System.Windows.Forms.Panel]::new()
$detail.Dock = 'Right'; $detail.Width = 322; $detail.BackColor = $col.bg2
$form.Controls.Add($detail)

$dName = [System.Windows.Forms.Label]::new()
$dName.SetBounds(14, 14, 294, 46); $dName.ForeColor = $col.fg
$dName.Font = [System.Drawing.Font]::new('Segoe UI', 10.5, [System.Drawing.FontStyle]::Bold)
$detail.Controls.Add($dName)

$dId = [System.Windows.Forms.Label]::new()
$dId.SetBounds(14, 62, 294, 18); $dId.ForeColor = $col.acc; $dId.Font = $fontMono
$detail.Controls.Add($dId)

$dPub = [System.Windows.Forms.Label]::new()
$dPub.SetBounds(14, 82, 294, 18); $dPub.ForeColor = $col.mut
$detail.Controls.Add($dPub)

$dDesc = [System.Windows.Forms.Label]::new()
$dDesc.SetBounds(14, 108, 294, 330); $dDesc.ForeColor = $col.fg
$detail.Controls.Add($dDesc)

$dHint = [System.Windows.Forms.Label]::new()
$dHint.SetBounds(14, 450, 294, 140); $dHint.ForeColor = $col.mut
$dHint.Text = ("Passa il mouse su una voce per leggere cosa fa." + "`r`n`r`n" +
    "CHRK. = quello che era gia sul tuo PC" + "`r`n" +
    "Extra = app nuove scelte da te" + "`r`n" +
    "Mouse fix = tweak del puntatore (MarkC)")
$detail.Controls.Add($dHint)

function Show-Detail($pkg) {
    if (-not $pkg) { return }
    $dName.Text = [string]$pkg.name
    $dId.Text = [string]$pkg.id
    $dPub.Text = if ($pkg.PSObject.Properties['pub'] -and $pkg.pub) { 'di ' + $pkg.pub } else { '' }
    $dDesc.Text = if ($pkg.PSObject.Properties['desc'] -and $pkg.desc) { [string]$pkg.desc } else { 'Nessuna descrizione disponibile.' }
    if ($pkg.kind -eq 'mouse') { $dDesc.Text = $dDesc.Text + "`r`n`r`n(Scrive le curve SmoothMouseX/Y e le soglie nel registro)" }
    $dHint.Text = ''
}

# --- lista ---
$scroll = [System.Windows.Forms.Panel]::new()
$scroll.Dock = 'Fill'; $scroll.AutoScroll = $true; $scroll.BackColor = $col.bg
$form.Controls.Add($scroll); $scroll.BringToFront()

$flow = [System.Windows.Forms.FlowLayoutPanel]::new()
$flow.Dock = 'Fill'; $flow.AutoScroll = $true; $flow.FlowDirection = 'TopDown'; $flow.WrapContents = $false
$flow.Padding = [System.Windows.Forms.Padding]::new(10)
$scroll.Controls.Add($flow)

$script:Checks = [System.Collections.Generic.List[object]]::new()
$catSeen = [System.Collections.Generic.List[string]]::new()
foreach ($p in $Packages) { if (-not $catSeen.Contains($p.cat)) { $catSeen.Add($p.cat) } }
foreach ($cat in $catSeen) {
    $items = @($Packages | Where-Object { $_.cat -eq $cat })
    $box = [System.Windows.Forms.GroupBox]::new()
    $box.Text = ("{0}  ({1})" -f $cat, $items.Count)
    $box.ForeColor = $col.acc; $box.Font = $fontBold
    $box.AutoSize = $true; $box.AutoSizeMode = 'GrowAndShrink'
    $box.Padding = [System.Windows.Forms.Padding]::new(10)
    $inner = [System.Windows.Forms.FlowLayoutPanel]::new()
    $inner.FlowDirection = 'TopDown'; $inner.WrapContents = $false; $inner.AutoSize = $true
    foreach ($p in $items) {
        $cb = [System.Windows.Forms.CheckBox]::new()
        $pre = switch ($p.preset) { 'mine' { '[CHRK.] ' } 'extra' { '[extra] ' } default { '' } }
        $cb.Text = ($pre + [string]$p.name)
        $cb.Tag = $p; $cb.AutoSize = $true; $cb.ForeColor = $col.fg; $cb.Font = $font
        $cb.Margin = [System.Windows.Forms.Padding]::new(2, 1, 2, 1)
        if ($p.desc) { $tip.SetToolTip($cb, [string]$p.desc) }
        $cb.Add_MouseEnter({ try { Show-Detail $this.Tag } catch { } })
        $script:Checks.Add([pscustomobject]@{ cb = $cb; pkg = $p })
        $inner.Controls.Add($cb)
    }
    $box.Controls.Add($inner)
    $flow.Controls.Add($box)
}

# --- stato interno ---
$script:Installed = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$script:Queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
$script:Handle = $null; $script:Total = 0; $script:Done = 0
$script:Ok = 0; $script:Skip = 0; $script:Fail = 0; $script:Start = $null
$script:CurName = ''

function Apply-Preset([string]$name) {
    if ($name -eq 'none') { Apply-Filter; return }
    $want = @(Get-Preset $name)
    foreach ($c in $script:Checks) {
        if ($want -notcontains $c.pkg.id) { $c.cb.Checked = $false; continue }
        if ($c.pkg.kind -eq 'pkg' -and $script:Installed.Contains($c.pkg.id) -and -not $chkForce.Checked) { $c.cb.Checked = $false; continue }
        $c.cb.Checked = $true
    }
    Apply-Filter
}
function Apply-Filter {
    $q = $txtSearch.Text.Trim().ToLower()
    $only = $chkOnly.Checked
    foreach ($c in $script:Checks) {
        $hay = ([string]$c.pkg.name + ' ' + [string]$c.pkg.id + ' ' + [string]$c.pkg.desc).ToLower()
        $c.cb.Visible = (((-not $q) -or $hay.Contains($q)) -and ((-not $only) -or $c.cb.Checked))
    }
}
function Write-Log([string]$m, $c = $null) {
    $log.SelectionStart = $log.TextLength; $log.SelectionLength = 0
    if ($c) { $log.SelectionColor = $c }
    $log.AppendText($m + "`r`n")
    $log.SelectionStart = $log.TextLength; $log.ScrollToCaret()
}
function Stamp { (Get-Date -Format 'HH:mm:ss') }

$workerCore = {
    param($MsgQ, $Ids, $Meta, $UpgradeAll)
    function Emit($o) { $MsgQ.Enqueue($o) }
    function HexToBytes([string]$hex) { return [byte[]](($hex -split ',' | Where-Object { $_ -ne '' }) | ForEach-Object { [Convert]::ToByte($_.Trim(), 16) }) }
    $admin = -1978335107
    $skip  = @{ -1978335135 = 'gia installato'; -1978335189 = 'nessun aggiornamento' }
    $rb    = @{ 3010 = 'installato, riavvio consigliato'; 1641 = 'installato, riavvio avviato'; -1978334967 = 'installato, riavvio consigliato'; -1978334965 = 'installato, riavvio avviato' }

    if ($UpgradeAll) {
        Emit @{ t = 'info'; m = 'winget upgrade --all' }
        $a = @('upgrade', '--all', '--accept-package-agreements', '--accept-source-agreements', '--include-unknown', '--silent')
        $p = Start-Process -FilePath winget -ArgumentList $a -NoNewWindow -Wait -PassThru
        Emit @{ t = 'res'; id = 'upgrade --all'; name = 'TUTTI i pacchetti'; out = $(if ($p.ExitCode -eq 0) { 'OK' } else { 'FAIL' }); det = ('exit {0}' -f $p.ExitCode) }
        Emit @{ t = 'done' }
        return
    }

    foreach ($id in $Ids) {
        $info = $Meta[$id]
        if (-not $info) { continue }
        Emit @{ t = 'pkg'; id = $id; name = $info.name; kind = $info.kind }

        if ($info.kind -eq 'mouse') {
            try {
                $base = 'HKCU:\Control Panel\Mouse'
                $def  = 'Registry::HKEY_USERS\.DEFAULT\Control Panel\Mouse'
                if ($info.x)     { Set-ItemProperty -Path $base -Name SmoothMouseXCurve -Type Binary -Value (HexToBytes $info.x) }
                if ($info.y)     { Set-ItemProperty -Path $base -Name SmoothMouseYCurve -Type Binary -Value (HexToBytes $info.y) }
                if ($info.sens)  { Set-ItemProperty -Path $base -Name MouseSensitivity   -Type String -Value $info.sens }
                if ($info.speed) { Set-ItemProperty -Path $def  -Name MouseSpeed      -Type String -Value $info.speed }
                if ($info.t1)    { Set-ItemProperty -Path $def  -Name MouseThreshold1 -Type String -Value $info.t1 }
                if ($info.t2)    { Set-ItemProperty -Path $def  -Name MouseThreshold2 -Type String -Value $info.t2 }
                Emit @{ t = 'res'; id = $id; name = $info.name; out = 'OK'; det = 'registro aggiornato (serve logoff/login)' }
            } catch {
                Emit @{ t = 'res'; id = $id; name = $info.name; out = 'FAIL'; det = $_.Exception.Message }
            }
            continue
        }

        $a = @('install', '--id', $id, '--exact', '--accept-package-agreements', '--accept-source-agreements', '--source', $info.src, '--silent')
        $p = Start-Process -FilePath winget -ArgumentList $a -NoNewWindow -Wait -PassThru
        $c = $p.ExitCode
        if ($c -eq 0) { $o = 'OK'; $d = 'installato' }
        elseif ($rb.ContainsKey($c)) { $o = 'OK'; $d = $rb[$c] }
        elseif ($skip.ContainsKey($c)) { $o = 'SKIP'; $d = $skip[$c] }
        elseif ($c -eq $admin) { $o = 'SKIP'; $d = 'installato per l''utente: serve senza elevazione' }
        else { $o = 'FAIL'; $d = ('winget 0x{0:X8}' -f $c) }
        Emit @{ t = 'res'; id = $id; name = $info.name; out = $o; det = $d }
    }
    Emit @{ t = 'done' }
}
$scanCore = {
    param($MsgQ, $Ids)
    function Emit($o) { $MsgQ.Enqueue($o) }
    Emit @{ t = 'info'; m = 'Scansione pacchetti installati...' }
    $txt = (winget list --accept-source-agreements --disable-interactivity 2>&1 | Out-String)
    foreach ($id in $Ids) {
        $inst = ($txt -match ('(?<!\S)' + [regex]::Escape($id) + '(?!\S)'))
        Emit @{ t = 'scan'; id = $id; inst = [bool]$inst }
    }
    Emit @{ t = 'scanDone' }
}

function Test-Busy { return [bool]($script:Handle -and -not $script:Handle.IsCompleted) }

function Start-Worker([string]$kind) {
    if (Test-Busy) { return }
    $script:Queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
    $ids = @($script:Checks | Where-Object { $_.cb.Checked } | ForEach-Object { $_.pkg.id })
    $meta = @{}
    foreach ($c in $script:Checks) {
        $meta[$c.pkg.id] = @{ name = $c.pkg.name; src = $c.pkg.src; kind = $c.pkg.kind
            x = $c.pkg.x; y = $c.pkg.y; sens = $c.pkg.sens; speed = $c.pkg.speed; t1 = $c.pkg.t1; t2 = $c.pkg.t2 }
    }
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'MTA'; $rs.ThreadOptions = 'ReuseThread'; $rs.Open()
    $rs.SessionStateProxy.SetVariable('MsgQ', $script:Queue)
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    if ($kind -eq 'scan') {
        $allIds = @($script:Checks | Where-Object { $_.pkg.kind -eq 'pkg' } | ForEach-Object { $_.pkg.id })
        [void]$ps.AddScript($scanCore).AddArgument($script:Queue).AddArgument($allIds)
        $lblStatus.Text = 'Scansione dei pacchetti installati...'
    }
    else {
        $script:Total = $ids.Count; $script:Done = 0
        $script:Ok = 0; $script:Skip = 0; $script:Fail = 0; $script:Start = Get-Date
        $progress.Maximum = [Math]::Max($ids.Count, 1); $progress.Value = 0
        [void]$ps.AddScript($workerCore).AddArgument($script:Queue).AddArgument($ids).AddArgument($meta).AddArgument(($kind -eq 'upgrade'))
        $lblStatus.Text = ("Avvio: 0/{0} pacchetti" -f $ids.Count)
    }
    $script:Ps = $ps; $script:Rs = $rs
    $script:Handle = $ps.BeginInvoke()
}

function Drain-Queue {
    $msg = $null
    while ($script:Queue.TryDequeue([ref]$msg)) {
        switch ($msg.t) {
            'info' { Write-Log ("[{0}] {1}" -f (Stamp), $msg.m) $col.mut }
            'pkg'  {
                $script:CurName = $msg.name
                Write-Log ("[{0}] > {1}" -f (Stamp), $msg.name) $col.acc
                Update-Status
            }
            'res'  {
                $script:Done++
                switch ($msg.out) { 'OK' { $script:Ok++ } 'SKIP' { $script:Skip++ } default { $script:Fail++ } }
                $c = switch ($msg.out) { 'OK' { $col.ok } 'SKIP' { $col.mut } default { $col.err } }
                Write-Log ("[{0}]   {1,-4} {2}  -  {3}" -f (Stamp), $msg.out, $msg.name, $msg.det) $c
                if ($progress.Maximum -gt 1) { $progress.Value = [Math]::Min($script:Done, $progress.Maximum) }
                Update-Status
            }
            'scan' { if ($msg.inst) { $script:Installed.Add($msg.id) } }
            'scanDone' {
                $n = 0
                foreach ($ch in $script:Checks) {
                    if ($ch.pkg.kind -eq 'pkg' -and $script:Installed.Contains($ch.pkg.id)) {
                        $ch.cb.Text = ($ch.cb.Text + '   [gia installato]'); $ch.cb.Checked = $false; $n++
                    }
                }
                # fix mouse gia applicati
                $applied = 0
                foreach ($ch in $script:Checks) {
                    if ($ch.pkg.kind -ne 'mouse' -or -not $ch.pkg.x) { continue }
                    if ((Get-CurrentCurveHex 'SmoothMouseXCurve') -eq $ch.pkg.x) {
                        $ch.cb.Text = ($ch.cb.Text + '   [gia applicato]'); $ch.cb.Checked = $false; $applied++
                    }
                }
                $lblScan.Text = ("{0} installati | {1} mouse" -f $n, $applied)
                Write-Log ("[{0}] Scansione: {1} pacchetti installati, {2} fix mouse gia applicati. ItemsSize rilevato: {3}%." -f (Stamp), $n, $applied, (Get-CurrentScale)) $col.mut
                Apply-Preset $Preset
                $lblStatus.Text = 'Pronto. Seleziona e premi APPLICA SELEZIONATI.'
            }
            'done' {
                $reboot = ($script:Fail -eq 0 -and $script:Total -gt 0)
                Write-Log ("[{0}] === FATTO: {1} OK, {2} saltati, {3} falliti ===" -f (Stamp), $script:Ok, $script:Skip, $script:Fail) $col.fg
                $msg2 = ("Fatto: {0} OK, {1} saltati, {2} falliti" -f $script:Ok, $script:Skip, $script:Fail)
                if ($script:Ok -gt 0) { $msg2 += ' - logoff/login per i fix mouse' }
                $lblStatus.Text = $msg2
                if ($script:Rs) { try { $script:Rs.Dispose() } catch {} }
            }
        }
    }
}
function Update-Status {
    if ($script:Total -le 0) { return }
    $pct = [int](100 * $script:Done / $script:Total)
    $extra = ''
    if ($script:Start -and $script:Done -gt 0) {
        $el = ((Get-Date) - $script:Start).TotalSeconds
        $avg = $el / $script:Done
        $eta = $avg * ($script:Total - $script:Done)
        $extra = ("  -  media {0:N0}s/pacchetto, ETA {1}" -f $avg, ([TimeSpan]::FromSeconds($eta)).ToString('mm\:ss'))
    }
    $cur = if ($script:Done -lt $script:Total -and $script:CurName) { " | in corso: $($script:CurName)" } else { '' }
    $lblStatus.Text = ("Avanzamento {0}/{1} ({2}%){3}{4}" -f $script:Done, $script:Total, $pct, $cur, $extra)
}

$timer = [System.Windows.Forms.Timer]::new()
$timer.Interval = 150
$timer.Add_Tick({ Drain-Queue })
$timer.Start()

# --- cronjob dialog ---
function Show-CronDialog {
    $d = [System.Windows.Forms.Form]::new()
    $d.Text = 'Aggiornamento automatico dei programmi'
    $d.Size = [System.Drawing.Size]::new(520, 400); $d.StartPosition = 'CenterParent'
    $d.BackColor = $col.bg2; $d.ForeColor = $col.fg; $d.Font = $font; $d.FormBorderStyle = 'FixedDialog'
    $d.MaximizeBox = $false; $d.MinimizeBox = $false

    $l1 = [System.Windows.Forms.Label]::new(); $l1.Text = 'Frequenza:'; $l1.SetBounds(16, 18, 90, 20); $d.Controls.Add($l1)
    $cmb = [System.Windows.Forms.ComboBox]::new(); $cmb.DropDownStyle = 'DropDownList'
    $cmb.SetBounds(110, 15, 200, 24); $cmb.BackColor = $col.bg3; $cmb.ForeColor = $col.fg
    [void]$cmb.Items.Add('Ogni giorno'); [void]$cmb.Items.Add('Ogni N giorni')
    $cmb.SelectedIndex = 1; $d.Controls.Add($cmb)

    $l2 = [System.Windows.Forms.Label]::new(); $l2.Text = 'N:'; $l2.SetBounds(330, 18, 20, 20); $d.Controls.Add($l2)
    $num = [System.Windows.Forms.NumericUpDown]::new(); $num.Minimum = 1; $num.Maximum = 30; $num.Value = 7
    $num.SetBounds(352, 15, 60, 24); $num.BackColor = $col.bg3; $num.ForeColor = $col.fg; $d.Controls.Add($num)

    $l3 = [System.Windows.Forms.Label]::new(); $l3.Text = 'Ora:'; $l3.SetBounds(16, 56, 90, 20); $d.Controls.Add($l3)
    $dtp = [System.Windows.Forms.DateTimePicker]::new(); $dtp.Format = 'Time'; $dtp.ShowUpDown = $true
    $dtp.SetBounds(110, 53, 120, 24)
    try { $dtp.Value = [datetime]::Today.AddHours(3) } catch {}
    $d.Controls.Add($dtp)

    $lExplain = [System.Windows.Forms.Label]::new()
    $lExplain.SetBounds(16, 88, 470, 56); $lExplain.ForeColor = $col.fg
    $lExplain.Text = ("Windows eseguira' da solo 'winget upgrade --all' ogni volta indicata qua sotto." + "`r`n" +
        "Non devi tenere aperto nulla: si occupa Windows." + "`r`n" +
        "Il risultato finisce nel file ninite-update.log accanto allo script.")
    $d.Controls.Add($lExplain)

    $info = [System.Windows.Forms.Label]::new(); $info.SetBounds(16, 150, 470, 76); $info.ForeColor = $col.mut
    $d.Controls.Add($info)

    function Refresh-Info {
        $st = Get-CronStatus
        $info.Text = if ($st) {
            "Attivo: '$TaskName'`nStato: $($st.State)`nProssima esecuzione: $((Get-ScheduledTaskInfo -TaskName $TaskName).NextRunTime)"
        } else { "Nessun aggiornamento pianificato." }
    }
    Refresh-Info

    $bCreate = New-Btn 'Attiva aggiornamento' 16 262 150 'primary'
    $bRun = New-Btn 'Esegui ora' 172 262 100
    $bDel = New-Btn 'Disattiva' 278 262 90
    $bClose = New-Btn 'Chiudi' 392 262 80
    foreach ($b in @($bCreate, $bRun, $bDel, $bClose)) { $d.Controls.Add($b) }

    $chkElev = [System.Windows.Forms.CheckBox]::new()
    $chkElev.Text = 'esegui con privilegi elevati (richiede admin, sconsigliato per winget)'
    $chkElev.SetBounds(16, 234, 460, 20); $chkElev.ForeColor = $col.mut
    $d.Controls.Add($chkElev)

    $bCreate.Add_Click({
        $days = if ($cmb.SelectedIndex -eq 0) { 1 } else { [int]$num.Value }
        $at = $dtp.Value.ToString('HH:mm')
        $num.Enabled = ($cmb.SelectedIndex -eq 1)
        try { [System.Windows.Forms.MessageBox]::Show((Install-Cron -everyDays $days -at $at -elevated:$chkElev.Checked), 'Pianificato', 'OK', 'Information') | Out-Null }
        catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Errore', 'OK', 'Error') | Out-Null }
        Refresh-Info
    })
    $bRun.Add_Click({
        try { Start-ScheduledTask -TaskName $TaskName; [System.Windows.Forms.MessageBox]::Show('Avviato.', 'OK', 'OK', 'Information') | Out-Null }
        catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Errore', 'OK', 'Error') | Out-Null }
    })
    $bDel.Add_Click({ try { [void](Remove-Cron); Refresh-Info } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Errore', 'OK', 'Error') | Out-Null } })
    $bClose.Add_Click({ $d.Close() })
    [void]$d.ShowDialog($form)
}

# --- eventi ---
$txtSearch.Add_TextChanged({ Apply-Filter })
$chkOnly.Add_CheckedChanged({ Apply-Filter })
$btnMine.Add_Click({ Apply-Preset 'mine' })
$btnExtra.Add_Click({ Apply-Preset 'extra' })
$btnMouse.Add_Click({ Apply-Preset 'mouse' })
$btnNone.Add_Click({ foreach ($c in $script:Checks) { $c.cb.Checked = $false }; Apply-Filter })
$btnCron.Add_Click({ Show-CronDialog })
$btnSelf.Add_Click({
    try {
        if ([System.Windows.Forms.MessageBox]::Show("Scaricare l'ultima versione da`n$script:UpdateUrl`n`ne sostituire questo file?", 'Aggiorna script', 'YesNo') -ne 'Yes') { return }
        $r = Update-Self
        Write-Log ("[{0}] {1}" -f (Stamp), $r) $col.ok
        [System.Windows.Forms.MessageBox]::Show($r, 'Aggiorna script', 'OK', 'Information') | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Aggiorna script', 'OK', 'Error') | Out-Null
    }
})
$lblVer.Add_Click({
    try {
        $rv = Get-RemoteVersion
        if ($null -eq $rv) { throw "Versione remota non trovata su $script:UpdateUrl" }
        $msg = if ($rv -eq $script:Version) { "Gia aggiornato (v$script:Version)." } else { "Disponibile v$rv (hai v$script:Version). Usa 'Aggiorna script'." }
        [System.Windows.Forms.MessageBox]::Show($msg, 'Versione', 'OK', 'Information') | Out-Null
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Versione', 'OK', 'Warning') | Out-Null }
})
$btnInstall.Add_Click({
    if (Test-Busy) { [System.Windows.Forms.MessageBox]::Show('Un lavoro e in corso.') | Out-Null; return }
    foreach ($c in $script:Checks) {
        if ($chkForce.Checked -and $c.cb.Text -like '*[installato]*') { $c.cb.Checked = $true }
    }
    $sel = @($script:Checks | Where-Object { $_.cb.Checked })
    if (-not $sel.Count) { [System.Windows.Forms.MessageBox]::Show('Nessun elemento selezionato.') | Out-Null; return }
    if ($DryRun) { Write-Log ('DRY-RUN: avrei applicato {0} elementi' -f $sel.Count) $col.warn; return }
    $pk = @($sel | Where-Object { $_.pkg.kind -eq 'pkg' }).Count
    $mx = @($sel | Where-Object { $_.pkg.kind -eq 'mouse' }).Count
    Write-Log ("[{0}] === AVVIO: {1} pacchetti, {2} fix mouse ===" -f (Stamp), $pk, $mx) $col.acc
    Start-Worker 'install'
})
$btnUpgrade.Add_Click({
    if (Test-Busy) { return }
    if ([System.Windows.Forms.MessageBox]::Show('Eseguire winget upgrade --all ?', 'Conferma', 'YesNo') -ne 'Yes') { return }
    Write-Log ("[{0}] === AGGIORNA TUTTO (winget upgrade --all) ===" -f (Stamp)) $col.acc
    Start-Worker 'upgrade'
})
$cmbCronRefresh = $null
$form.Add_Shown({
    Write-Log ("[{0}] ItemsSize rilevato: {1}%   |   (Ctrl+A non serve, usa i pulsanti di selezione)" -f (Stamp), (Get-CurrentScale)) $col.mut
    if ($Preset -ne 'none') { Apply-Preset $Preset }
    Start-Worker 'scan'
})
$form.Add_FormClosing({
    if (Test-Busy) {
        if ([System.Windows.Forms.MessageBox]::Show('Un lavoro e in corso. Chiudere lo stesso?', 'Conferma', 'YesNo') -ne 'Yes') { $_.Cancel = $true }
    }
})

[void]$form.ShowDialog()
$timer.Stop()
