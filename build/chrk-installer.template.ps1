<#
    CHRK-Installer.ps1  -  installer winget con GUI  +  fix mouse MarkC
    https://github.com/cchrkk/chrk-installer

    PUBBLICAZIONE / INSTALL DA URL
      Il file e' servito su un URL corto (Cloudflare -> GitHub), quindi basta:
        irm https://s.chrk.tk | iex
      Lo script, se eseguito in memoria, si copia da solo in
        %LOCALAPPDATA%\CHRK-Installer\CHRK-Installer.ps1
      e si riavvia da li' (serve per cronjob e auto-aggiornamento).
      Il file e' AUTOCONTENUTO: catalogo e logo sono embeddati, unica dipendenza winget.

    FUNZIONI
      - GUI: rail delle categorie a sinistra, lista con le intestazioni di categoria,
        pannello descrizione a destra, avanzamento e log in basso
      - lista selezionabile di pacchetti winget e di fix mouse
      - rileva cio' che e' GIA' installato/applicato e lo salta
      - avanzamento chiaro: pacchetto corrente, n/total, %, ETA, esito per pacchetto
      - "Aggiorna tutto" (winget upgrade --all)
      - aggiornamento automatico: sezione dedicata dentro la lista (Task Scheduler)
      - modalita' console per script e per il cronjob

    USO
        .\CHRK-Installer.ps1                      # GUI
        .\CHRK-Installer.ps1 -Preset recommended  # GUI con la base consigliata preselezionata
        .\CHRK-Installer.ps1 -Preset mine         # GUI con la mia lista
        .\CHRK-Installer.ps1 -Preset mouse        # GUI coi fix mouse consigliati
        .\CHRK-Installer.ps1 -Console             # elenco a console
        .\CHRK-Installer.ps1 -Console -Preset recommended -DryRun
        .\CHRK-Installer.ps1 -Select 'Git.Git','mouse-1to1-100' -Console
        .\CHRK-Installer.ps1 -UpgradeAll                       # aggiorna tutto (usato dal cronjob)
        .\CHRK-Installer.ps1 -InstallCron -EveryDays 7 -CronTime 03:00
        .\CHRK-Installer.ps1 -RemoveCron

    Logica install ripresa da winutil.ps1 (exit code, msstore, --silent).
    Fix mouse: valori estratti da MarkC Mouse Fix Builder 2.6.
#>
[CmdletBinding()]
param(
    [string[]]$Select,
    # recommended/ez = base della guida EZ | mine = la mia lista | extra = scelte a mano
    [ValidateSet('recommended', 'ez', 'mine', 'extra', 'mouse', 'all', 'none')]
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
$TaskName = 'CHRK-Installer Update'
$script:Version   = '__VERSION__'
$script:UpdateUrl = '__UPDATE_URL__'

# ==== UN SOLO FILE: se eseguito in memoria (irm ... | iex) si installa da solo =
if (-not $PSCommandPath -and -not $NoSelfInstall) {
    $dirDst = Join-Path $env:LOCALAPPDATA 'CHRK-Installer'
    $dst    = Join-Path $dirDst 'CHRK-Installer.ps1'
    Write-Host ("CHRK-Installer v{0} - esecuzione in memoria (irm | iex)" -f $script:Version) -ForegroundColor Cyan
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
        # Su un Windows appena installato l'ExecutionPolicy e' Restricted: un .ps1 su disco non
        # parte (mentre irm | iex funziona, perche' non e' un file). Il Bypass vale solo per
        # questo processo e non richiede admin. Se una policy di gruppo lo impedisce si esegue
        # il contenuto in memoria: la GUI funziona, cronjob e auto-update no (vogliono un file).
        try { Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop } catch { }
        if ((Get-ExecutionPolicy) -eq 'Bypass') {
            Write-Host "Avvio dalla copia locale (da qui in poi hai un solo file su disco)..." -ForegroundColor Green
            & $dst @fwd
        } else {
            Write-Host "Questo PC blocca l esecuzione degli script: eseguo la copia locale in memoria." -ForegroundColor Yellow
            Write-Host "Cronjob e auto-aggiornamento restano spenti. Per averli:" -ForegroundColor Yellow
            Write-Host ("  powershell -ExecutionPolicy Bypass -File `"{0}`"" -f $dst) -ForegroundColor Gray
            $fwd['NoSelfInstall'] = $true
            & ([ScriptBlock]::Create([System.IO.File]::ReadAllText($dst))) @fwd
        }
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
        'recommended' { return @($Packages | Where-Object { $_.ez -eq '1' } | Select-Object -ExpandProperty id) }
        'ez'          { return @($Packages | Where-Object { $_.ez -eq '1' } | Select-Object -ExpandProperty id) }
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
function Get-CronLogPath {
    if ($LogFile) { return $LogFile }
    if (-not $PSCommandPath) { return 'chrk-update.log' }
    return (Join-Path (Split-Path $PSCommandPath) 'chrk-update.log')
}
function Install-Cron([int]$everyDays, [string]$at, [switch]$elevated) {
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) { throw "Percorso dello script non disponibile (esecuzione in memoria). Salva il file su disco e riprova." }
    if (-not (Test-Path $scriptPath)) { throw "File dello script non trovato: $scriptPath" }
    if ($elevated -and -not (Test-Admin)) { throw "Per un task elevato serve PowerShell come Amministratore. Riprova senza elevazione (consigliato per winget)." }

    $logPath = Get-CronLogPath
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
                -Description 'Aggiorna tutti i pacchetti winget (CHRK-Installer).' -Force -ErrorAction Stop | Out-Null
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
    if ($remote -notmatch 'CHRK-Installer') { throw "Il file scaricato non sembra CHRK-Installer." }
    $cur = [System.IO.File]::ReadAllText($PSCommandPath)
    if ($cur -eq $remote) { return "Gia aggiornato (v$($script:Version))." }
    $rv = if ($remote -match "(?m)\`$script:Version\s*=\s*'([^']+)'") { $Matches[1] } else { '?' }
    Copy-Item $PSCommandPath "$PSCommandPath.bak" -Force
    [System.IO.File]::WriteAllText($PSCommandPath, $remote, [System.Text.UTF8Encoding]::new($false))
    return "Aggiornato: v$($script:Version) -> v$rv (backup in $PSCommandPath.bak). Riavvia lo script."
}

# ==== branch CLI ============================================================
if ($ShowVersion) { Write-Host ("CHRK-Installer v{0}" -f $script:Version); return }
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
    bg    = [System.Drawing.ColorTranslator]::FromHtml('#11131a')
    bg2   = [System.Drawing.ColorTranslator]::FromHtml('#171a23')
    bg3   = [System.Drawing.ColorTranslator]::FromHtml('#1e222e')
    inp   = [System.Drawing.ColorTranslator]::FromHtml('#0d0f15')
    fg    = [System.Drawing.ColorTranslator]::FromHtml('#e6e8ee')
    mut   = [System.Drawing.ColorTranslator]::FromHtml('#9aa2b5')
    acc   = [System.Drawing.ColorTranslator]::FromHtml('#4c9aff')
    ok    = [System.Drawing.ColorTranslator]::FromHtml('#3fb950')
    warn  = [System.Drawing.ColorTranslator]::FromHtml('#d29922')
    err   = [System.Drawing.ColorTranslator]::FromHtml('#f85149')
}
$font      = [System.Drawing.Font]::new('Segoe UI', 9, [System.Drawing.FontStyle]::Regular)
$fontBold  = [System.Drawing.Font]::new('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
$fontTitle = [System.Drawing.Font]::new('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
$fontH2    = [System.Drawing.Font]::new('Segoe UI', 10.5, [System.Drawing.FontStyle]::Bold)
$fontSmall = [System.Drawing.Font]::new('Segoe UI', 8, [System.Drawing.FontStyle]::Regular)
$fontMono  = [System.Drawing.Font]::new('Consolas', 8.5, [System.Drawing.FontStyle]::Regular)

$form = [System.Windows.Forms.Form]::new()
$form.Text = 'CHRK Installer  -  winget + fix mouse MarkC'
$form.Size = [System.Drawing.Size]::new(1200, 840)
$form.MinimumSize = [System.Drawing.Size]::new(1020, 690)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $col.bg
$form.ForeColor = $col.fg
$form.Font = $font

$tip = [System.Windows.Forms.ToolTip]::new()
$tip.AutoPopDelay = 20000; $tip.InitialDelay = 220; $tip.ReshowDelay = 80

function New-Label {
    param([string]$Text, $Fore, [int]$Height = 18, $UseFont = $null)
    $l = [System.Windows.Forms.Label]::new()
    $l.Text = $Text; $l.ForeColor = $Fore; $l.AutoSize = $false
    $l.Height = $Height; $l.TextAlign = 'MiddleLeft'
    if ($UseFont) { $l.Font = $UseFont }
    return $l
}
function New-Btn {
    param([string]$Text, [int]$Width, [int]$Height = 28, [string]$Kind = 'ghost')
    $b = [System.Windows.Forms.Button]::new()
    $b.Text = $Text; $b.FlatStyle = 'Flat'; $b.Height = $Height; $b.Width = $Width
    $b.FlatAppearance.BorderColor = $col.bg3
    if ($Kind -eq 'primary') { $b.BackColor = $col.acc; $b.ForeColor = [System.Drawing.Color]::White }
    else { $b.BackColor = $col.bg3; $b.ForeColor = $col.fg }
    return $b
}
function New-Flow {
    param([string]$Direction = 'LeftToRight')
    $f = [System.Windows.Forms.FlowLayoutPanel]::new()
    $f.FlowDirection = $Direction; $f.WrapContents = $false; $f.AutoSize = $false
    $f.Margin = [System.Windows.Forms.Padding]::new(0)
    return $f
}

# --- barra superiore: logo, titolo, ricerca, azioni -------------------------
$top = [System.Windows.Forms.Panel]::new()
$top.Dock = 'Top'; $top.Height = 100; $top.BackColor = $col.bg2
$top.Padding = [System.Windows.Forms.Padding]::new(12, 10, 12, 10)

$topRight = [System.Windows.Forms.Panel]::new()
$topRight.Dock = 'Right'; $topRight.Width = 348; $topRight.BackColor = $col.bg2

$rowBtns = New-Flow 'RightToLeft'
$rowBtns.Dock = 'Bottom'; $rowBtns.Height = 36; $rowBtns.BackColor = $col.bg2
$btnInstall = New-Btn 'APPLICA SELEZIONATI' 190 30 'primary'
$btnUpgrade = New-Btn 'Aggiorna tutto' 140 30
$btnInstall.Margin = [System.Windows.Forms.Padding]::new(8, 4, 0, 0)
$btnUpgrade.Margin = [System.Windows.Forms.Padding]::new(8, 4, 0, 0)
$rowBtns.Controls.Add($btnInstall)
$rowBtns.Controls.Add($btnUpgrade)

$rowInfo = New-Flow 'RightToLeft'
$rowInfo.Dock = 'Bottom'; $rowInfo.Height = 22; $rowInfo.BackColor = $col.bg2
$lblVer = New-Label ("v{0}  -  verifica aggiornamenti" -f $script:Version) $col.acc 18
$lblVer.AutoSize = $true; $lblVer.Cursor = 'Hand'
$lblVer.Margin = [System.Windows.Forms.Padding]::new(8, 0, 0, 0)
$rowInfo.Controls.Add($lblVer)

$topRight.Controls.Add($rowInfo)
$topRight.Controls.Add($rowBtns)

$logoBox = [System.Windows.Forms.PictureBox]::new()
$logoBox.Dock = 'Left'; $logoBox.Width = 168; $logoBox.SizeMode = 'Zoom'
$logoBox.BackColor = $col.bg2
$logoBox.Padding = [System.Windows.Forms.Padding]::new(0, 8, 14, 8)
try {
    $bytes = [Convert]::FromBase64String($LogoB64)
    $ms = [System.IO.MemoryStream]::new($bytes, $false)
    $logoBox.Image = [System.Drawing.Image]::FromStream($ms)
} catch { }

$mid = [System.Windows.Forms.Panel]::new()
$mid.Dock = 'Fill'; $mid.BackColor = $col.bg2

$titleWrap = [System.Windows.Forms.Panel]::new()
$titleWrap.Dock = 'Top'; $titleWrap.Height = 50; $titleWrap.BackColor = $col.bg2
$lblTitle = New-Label 'CHRK Installer' $col.fg 30 $fontTitle
$lblTitle.Dock = 'Top'
$lblSub = New-Label 'Installa e aggiorna i programmi con winget. Le voci gia presenti vengono saltate.' $col.mut 18
$lblSub.Dock = 'Top'
$titleWrap.Controls.Add($lblSub)
$titleWrap.Controls.Add($lblTitle)

$searchRow = New-Flow 'LeftToRight'
$searchRow.Dock = 'Top'; $searchRow.Height = 34; $searchRow.BackColor = $col.bg2
$txtSearch = [System.Windows.Forms.TextBox]::new()
$txtSearch.Width = 300; $txtSearch.BackColor = $col.inp; $txtSearch.ForeColor = $col.fg
$txtSearch.BorderStyle = 'FixedSingle'
$txtSearch.Margin = [System.Windows.Forms.Padding]::new(0, 5, 12, 0)
$chkForce = [System.Windows.Forms.CheckBox]::new()
$chkForce.Text = 'reinstalla se presente'; $chkForce.AutoSize = $true; $chkForce.ForeColor = $col.mut
$chkForce.Margin = [System.Windows.Forms.Padding]::new(6, 9, 12, 0)
$chkOnly = [System.Windows.Forms.CheckBox]::new()
$chkOnly.Text = 'solo selezionati'; $chkOnly.AutoSize = $true; $chkOnly.ForeColor = $col.mut
$chkOnly.Margin = [System.Windows.Forms.Padding]::new(6, 9, 12, 0)
$searchRow.Controls.Add($txtSearch)
$searchRow.Controls.Add($chkForce)
$searchRow.Controls.Add($chkOnly)

$mid.Controls.Add($searchRow)
$mid.Controls.Add($titleWrap)

$top.Controls.Add($mid)
$top.Controls.Add($logoBox)
$top.Controls.Add($topRight)

$tip.SetToolTip($btnInstall, 'Installa i pacchetti e applica i fix mouse selezionati.')
$tip.SetToolTip($btnUpgrade, 'Aggiorna TUTTI i programmi installati (winget upgrade --all).')
$tip.SetToolTip($chkForce, 'Se spuntato, reinstalla anche cio che risulta gia presente.')
$tip.SetToolTip($chkOnly, 'Mostra solo le voci selezionate.')
$tip.SetToolTip($lblVer, 'Confronta la tua versione con quella pubblicata su internet.')

# --- rail sinistro: categorie + selezione rapida ---------------------------
$rail = [System.Windows.Forms.Panel]::new()
$rail.Dock = 'Left'; $rail.Width = 240; $rail.BackColor = $col.bg2
$rail.Padding = [System.Windows.Forms.Padding]::new(10, 12, 10, 12)

$lstCats = [System.Windows.Forms.ListBox]::new()
$lstCats.Dock = 'Fill'; $lstCats.BorderStyle = 'None'; $lstCats.BackColor = $col.bg2
$lstCats.ForeColor = $col.fg; $lstCats.DrawMode = 'OwnerDrawFixed'; $lstCats.ItemHeight = 26
$lstCats.IntegralHeight = $false; $lstCats.TabStop = $false

$lblCats = New-Label 'CATEGORIE' $col.mut 22 $fontSmall
$lblCats.Dock = 'Top'

$railFoot = [System.Windows.Forms.Panel]::new()
$railFoot.Dock = 'Bottom'; $railFoot.Height = 182; $railFoot.BackColor = $col.bg2

$footFlow = New-Flow 'TopDown'
$footFlow.Dock = 'Fill'; $footFlow.BackColor = $col.bg2
$lblQuick = New-Label 'SELEZIONE RAPIDA' $col.mut 20 $fontSmall
$lblQuick.Width = 208
$lblQuick.Margin = [System.Windows.Forms.Padding]::new(0, 10, 0, 2)
$btnRec = New-Btn 'Consigliati' 212 28
$btnRec.Margin = [System.Windows.Forms.Padding]::new(0, 1, 0, 1)

$mineRow = New-Flow 'LeftToRight'
$mineRow.Width = 214; $mineRow.Height = 32
$btnMine = New-Btn 'CHRK.' 100 28
$btnMine.Margin = [System.Windows.Forms.Padding]::new(0, 1, 6, 1)
$btnExtra = New-Btn 'Extra' 100 28
$btnExtra.Margin = [System.Windows.Forms.Padding]::new(0, 1, 0, 1)
$mineRow.Controls.Add($btnMine)
$mineRow.Controls.Add($btnExtra)

$mouseRow = New-Flow 'LeftToRight'
$mouseRow.Width = 214; $mouseRow.Height = 30
$btnMouseP = New-Btn 'Mouse fix' 212 28
$btnMouseP.Margin = [System.Windows.Forms.Padding]::new(0, 1, 0, 1)
$mouseRow.Controls.Add($btnMouseP)

$lblScan = New-Label 'scansione in corso...' $col.mut 22 $fontSmall
$lblScan.Width = 212
$lblScan.Margin = [System.Windows.Forms.Padding]::new(0, 6, 0, 2)
$btnSelf = New-Btn 'Aggiorna script' 212 26
$btnSelf.Margin = [System.Windows.Forms.Padding]::new(0, 1, 0, 1)

$footFlow.Controls.Add($lblQuick)
$footFlow.Controls.Add($btnRec)
$footFlow.Controls.Add($mineRow)
$footFlow.Controls.Add($mouseRow)
$footFlow.Controls.Add($lblScan)
$footFlow.Controls.Add($btnSelf)
$railFoot.Controls.Add($footFlow)

$rail.Controls.Add($lstCats)
$rail.Controls.Add($lblCats)
$rail.Controls.Add($railFoot)

$tip.SetToolTip($btnRec, 'Le app di base, quelle della guida EZ (x.chrk.tk/ez): browser, VLC, 7zip, Steam, Git, editor, utility.')
$tip.SetToolTip($btnMine, 'La mia lista: quello che avevo installato sul mio PC (export winget).')
$tip.SetToolTip($btnExtra, 'Le app che ho scelto a mano oltre alla mia lista.')
$tip.SetToolTip($btnMouseP, 'Mouse fix MarkC: toglie l accelerazione del puntatore. Rileva la tua scala DPI.')
$tip.SetToolTip($btnSelf, 'Riscarica l ultima versione dello script da internet.')

# --- lista centrale --------------------------------------------------------
$listHost = [System.Windows.Forms.Panel]::new()
$listHost.Dock = 'Fill'; $listHost.BackColor = $col.bg
$listHost.Padding = [System.Windows.Forms.Padding]::new(12, 10, 8, 10)

$flow = [System.Windows.Forms.FlowLayoutPanel]::new()
$flow.Dock = 'Fill'; $flow.AutoScroll = $true; $flow.FlowDirection = 'TopDown'
$flow.WrapContents = $false; $flow.BackColor = $col.bg
$flow.Padding = [System.Windows.Forms.Padding]::new(8, 6, 8, 6)

$listHead = [System.Windows.Forms.Panel]::new()
$listHead.Dock = 'Top'; $listHead.Height = 34; $listHead.BackColor = $col.bg

$lblCatHead = New-Label 'Tutte le app' $col.fg 32 $fontH2
$lblCatHead.Dock = 'Fill'

$headRight = New-Flow 'RightToLeft'
$headRight.Dock = 'Right'; $headRight.Width = 340; $headRight.Height = 32
$headRight.BackColor = $col.bg
$lblSelCount = New-Label '0 selezionati' $col.mut 32
$lblSelCount.AutoSize = $true
$lblSelCount.TextAlign = 'MiddleRight'
$lblSelCount.Margin = [System.Windows.Forms.Padding]::new(0, 0, 10, 0)
$btnClear = New-Btn 'Pulisci selezione' 150 26
$btnClear.Margin = [System.Windows.Forms.Padding]::new(0, 3, 0, 0)
$headRight.Controls.Add($lblSelCount)
$headRight.Controls.Add($btnClear)

$listHead.Controls.Add($lblCatHead)
$listHead.Controls.Add($headRight)

# --- sezione "Aggiornamenti automatici" (dentro la lista) ------------------
$panelUpdates = [System.Windows.Forms.Panel]::new()
$panelUpdates.Dock = 'Fill'; $panelUpdates.BackColor = $col.bg
$panelUpdates.Visible = $false

$updFlow = New-Flow 'TopDown'
$updFlow.Dock = 'Fill'; $updFlow.BackColor = $col.bg
$updFlow.AutoScroll = $true
$updFlow.Padding = [System.Windows.Forms.Padding]::new(8, 6, 8, 6)

$lblUpdTitle = New-Label 'Aggiornamento automatico dei programmi' $col.fg 32 $fontH2
$lblUpdTitle.Width = 640
$lblUpdTitle.Margin = [System.Windows.Forms.Padding]::new(0, 0, 0, 6)
$lblUpdDesc = New-Label ("Un task di Windows esegue 'winget upgrade --all' quando vuoi tu." + "`r`n" +
    'Non serve tenere aperto nulla: se ne occupa Windows, anche a PC appena acceso.' + "`r`n" +
    'Il log dell esecuzione automatica finisce in un file accanto allo script.') $col.mut 70
$lblUpdDesc.Width = 660
$lblUpdDesc.Margin = [System.Windows.Forms.Padding]::new(0, 0, 0, 10)

$chkUpdOn = [System.Windows.Forms.CheckBox]::new()
$chkUpdOn.Text = 'Mantieni i programmi aggiornati automaticamente'
$chkUpdOn.AutoSize = $true; $chkUpdOn.ForeColor = $col.fg
$chkUpdOn.Font = $fontBold
$chkUpdOn.Margin = [System.Windows.Forms.Padding]::new(0, 2, 0, 10)

$updWhen = New-Flow 'LeftToRight'
$updWhen.Width = 660; $updWhen.Height = 32
$lblEvery = New-Label 'Ogni' $col.fg 26
$lblEvery.Width = 40
$lblEvery.Margin = [System.Windows.Forms.Padding]::new(6, 3, 4, 0)
$numDays = [System.Windows.Forms.NumericUpDown]::new()
$numDays.Minimum = 1; $numDays.Maximum = 60; $numDays.Value = 7; $numDays.Width = 60
$numDays.BackColor = $col.inp; $numDays.ForeColor = $col.fg
$numDays.Margin = [System.Windows.Forms.Padding]::new(0, 3, 4, 0)
$lblDays = New-Label 'giorni, alle' $col.fg 26
$lblDays.Width = 90
$lblDays.Margin = [System.Windows.Forms.Padding]::new(0, 3, 4, 0)
$dtpTime = [System.Windows.Forms.DateTimePicker]::new()
$dtpTime.Format = 'Custom'; $dtpTime.CustomFormat = 'HH:mm'
$dtpTime.ShowUpDown = $true; $dtpTime.Width = 110
try { $dtpTime.Value = [datetime]::Today.AddHours(3) } catch {}
$dtpTime.Margin = [System.Windows.Forms.Padding]::new(0, 3, 0, 0)
$updWhen.Controls.Add($lblEvery)
$updWhen.Controls.Add($numDays)
$updWhen.Controls.Add($lblDays)
$updWhen.Controls.Add($dtpTime)

$chkElev = [System.Windows.Forms.CheckBox]::new()
$chkElev.Text = 'esegui con privilegi elevati (richiede admin, sconsigliato con winget)'
$chkElev.AutoSize = $true; $chkElev.ForeColor = $col.mut
$chkElev.Margin = [System.Windows.Forms.Padding]::new(0, 10, 0, 8)

$lblUpdState = New-Label 'Stato: ...' $col.mut 36
$lblUpdState.Width = 660
$lblUpdState.Margin = [System.Windows.Forms.Padding]::new(0, 2, 0, 2)
$lblLogPath = New-Label '' $col.mut 20 $fontSmall
$lblLogPath.Width = 660
$lblLogPath.Margin = [System.Windows.Forms.Padding]::new(0, 0, 0, 10)

$updBtns = New-Flow 'LeftToRight'
$updBtns.Width = 660; $updBtns.Height = 34
$btnUpdSave = New-Btn 'Salva impostazioni' 170 30 'primary'
$btnUpdSave.Margin = [System.Windows.Forms.Padding]::new(0, 1, 8, 1)
$btnUpdRun = New-Btn 'Esegui adesso' 130 30
$btnUpdRun.Margin = [System.Windows.Forms.Padding]::new(0, 1, 8, 1)
$btnUpdRefresh = New-Btn 'Ricarica stato' 130 30
$btnUpdRefresh.Margin = [System.Windows.Forms.Padding]::new(0, 1, 8, 1)
$updBtns.Controls.Add($btnUpdSave)
$updBtns.Controls.Add($btnUpdRun)
$updBtns.Controls.Add($btnUpdRefresh)

$updFlow.Controls.Add($lblUpdTitle)
$updFlow.Controls.Add($lblUpdDesc)
$updFlow.Controls.Add($chkUpdOn)
$updFlow.Controls.Add($updWhen)
$updFlow.Controls.Add($chkElev)
$updFlow.Controls.Add($lblUpdState)
$updFlow.Controls.Add($lblLogPath)
$updFlow.Controls.Add($updBtns)
$panelUpdates.Controls.Add($updFlow)

$script:UpdWidth = 0
$updFlow.Add_Resize({
    $w = $updFlow.ClientSize.Width - 28
    if ($w -lt 240) { $w = 240 }
    if ($w -eq $script:UpdWidth) { return }
    $script:UpdWidth = $w
    foreach ($c in @($lblUpdTitle, $lblUpdDesc, $lblUpdState, $lblLogPath, $updWhen, $updBtns)) { $c.Width = $w }
})

$listHost.Controls.Add($flow)
$listHost.Controls.Add($panelUpdates)
$listHost.Controls.Add($listHead)

$tip.SetToolTip($chkUpdOn, 'Crea o rimuove il task di Windows che aggiorna i programmi da solo.')

# --- pannello dettaglio (destra) -------------------------------------------
$detail = [System.Windows.Forms.Panel]::new()
$detail.Dock = 'Right'; $detail.Width = 330; $detail.BackColor = $col.bg2
$detail.Padding = [System.Windows.Forms.Padding]::new(16, 14, 16, 14)

$dDesc = New-Label '' $col.fg 200
$dDesc.Dock = 'Fill'
$dTags = New-Label '' $col.acc 20
$dTags.Dock = 'Top'
$dPub = New-Label '' $col.mut 18
$dPub.Dock = 'Top'
$dId = New-Label '' $col.acc 18 $fontMono
$dId.Dock = 'Top'
$dName = New-Label '' $col.fg 52 $fontH2
$dName.Dock = 'Top'
$dLegend = New-Label ("Passa il mouse su una voce per leggerne la descrizione." + "`r`n`r`n" +
    'Consigliati = la base della guida EZ (x.chrk.tk/ez).' + "`r`n" +
    'CHRK. = quello che avevo sul mio PC.' + "`r`n" +
    'Extra = app scelte a mano oltre alla mia lista.' + "`r`n" +
    '(gia installato) = verra saltato.') $col.mut 116 $fontSmall
$dLegend.Dock = 'Bottom'

$detail.Controls.Add($dDesc)
$detail.Controls.Add($dTags)
$detail.Controls.Add($dPub)
$detail.Controls.Add($dId)
$detail.Controls.Add($dName)
$detail.Controls.Add($dLegend)

function Show-Detail($pkg) {
    if (-not $pkg) { return }
    $dName.Text = [string]$pkg.name
    $dId.Text = [string]$pkg.id
    $dPub.Text = if ($pkg.PSObject.Properties['pub'] -and $pkg.pub) { 'di ' + $pkg.pub } else { '' }
    $tags = @()
    if ($pkg.PSObject.Properties['ez'] -and $pkg.ez -eq '1') { $tags += 'consigliata' }
    if ($pkg.preset -eq 'mine') { $tags += 'CHRK.' }
    if ($pkg.preset -eq 'extra') { $tags += 'extra' }
    if ($pkg.kind -eq 'mouse') { $tags += 'mouse fix' }
    $tag = [string]$pkg.cat
    if ($tags.Count) { $tag = $tag + '  -  ' + ($tags -join ', ') }
    $dTags.Text = $tag
    $dDesc.Text = if ($pkg.PSObject.Properties['desc'] -and $pkg.desc) { [string]$pkg.desc } else { 'Nessuna descrizione disponibile.' }
    if ($pkg.kind -eq 'mouse') { $dDesc.Text = $dDesc.Text + "`r`n`r`n(Scrive le curve SmoothMouseX/Y e le soglie nel registro)" }
}

# --- pannello inferiore: avanzamento + log ---------------------------------
$bottom = [System.Windows.Forms.Panel]::new()
$bottom.Dock = 'Bottom'; $bottom.Height = 200; $bottom.BackColor = $col.bg2
$bottom.Padding = [System.Windows.Forms.Padding]::new(12, 8, 12, 8)

$log = [System.Windows.Forms.RichTextBox]::new()
$log.Dock = 'Fill'; $log.ReadOnly = $true; $log.ScrollBars = 'Vertical'; $log.WordWrap = $false
$log.BackColor = $col.inp; $log.ForeColor = $col.fg; $log.Font = $fontMono

$lblStatus = New-Label 'Pronto.' $col.fg 20 $fontBold
$lblStatus.Dock = 'Top'

$progress = [System.Windows.Forms.ProgressBar]::new()
$progress.Dock = 'Top'; $progress.Height = 14; $progress.Style = 'Continuous'
$progress.Visible = $false

$bottom.Controls.Add($log)
$bottom.Controls.Add($lblStatus)
$bottom.Controls.Add($progress)

$form.Controls.Add($listHost)
$form.Controls.Add($detail)
$form.Controls.Add($rail)
$form.Controls.Add($bottom)
$form.Controls.Add($top)

# --- costruzione della lista pacchetti ------------------------------------
$script:Rows  = [System.Collections.Generic.List[object]]::new()
$script:Heads = [System.Collections.Generic.List[object]]::new()
$script:ActiveCat = '*'

$script:CatOrder = @()
foreach ($p in $Packages) { if ($script:CatOrder -notcontains $p.cat) { $script:CatOrder += $p.cat } }

foreach ($cat in $script:CatOrder) {
    $items = @($Packages | Where-Object { $_.cat -eq $cat })
    $head = New-Label ('  ' + $cat) $col.acc 26 $fontBold
    $head.BackColor = $col.bg3
    $head.Margin = [System.Windows.Forms.Padding]::new(2, 8, 2, 4)
    $head.Width = 240
    $flow.Controls.Add($head)
    $catRows = [System.Collections.Generic.List[object]]::new()
    foreach ($p in $items) {
        $cb = [System.Windows.Forms.CheckBox]::new()
        $cb.Text = [string]$p.name
        $cb.AutoSize = $false; $cb.Height = 24; $cb.Width = 240
        $cb.ForeColor = $col.fg; $cb.Font = $font
        $cb.Padding = [System.Windows.Forms.Padding]::new(4, 0, 0, 0)
        $cb.Margin = [System.Windows.Forms.Padding]::new(2, 1, 2, 1)
        if ($p.desc) { $tip.SetToolTip($cb, [string]$p.desc) }
        $row = [pscustomobject]@{ cb = $cb; pkg = $p; cat = $cat; head = $head; base = [string]$p.name }
        $cb.Tag = $row
        $cb.Add_MouseEnter({ try { Show-Detail $this.Tag.pkg } catch { } })
        $cb.Add_CheckedChanged({ try { Update-SelCount } catch { } })
        $catRows.Add($row)
        $flow.Controls.Add($cb)
    }
    foreach ($r in $catRows) { $script:Rows.Add($r) }
    $script:Heads.Add([pscustomobject]@{ lbl = $head; cat = $cat; rows = $catRows; count = $items.Count })
}

# --- rail: voci ------------------------------------------------------------
$railItems = [System.Collections.Generic.List[object]]::new()
$railItems.Add([pscustomobject]@{ Kind = 'cron'; Cat = $null; Label = 'Aggiornamenti automatici'; Count = -1 })
$railItems.Add([pscustomobject]@{ Kind = 'all'; Cat = '*'; Label = 'Tutte le app'; Count = $script:Rows.Count })
foreach ($h in $script:Heads) {
    $railItems.Add([pscustomobject]@{ Kind = 'cat'; Cat = $h.cat; Label = $h.cat; Count = $h.count })
}
foreach ($it in $railItems) { [void]$lstCats.Items.Add($it) }

$lstCats.Add_DrawItem({
    param($sender, $e)
    if ($e.Index -lt 0 -or $e.Index -ge $sender.Items.Count) { return }
    $it = $sender.Items[$e.Index]
    $sel = (([int]$e.State -band 1) -eq 1)
    $back = if ($sel) { $col.acc } else { $col.bg2 }
    $fore = if ($sel) { [System.Drawing.Color]::White } else { $col.fg }
    if ($it.Kind -eq 'cron') { $fore = if ($sel) { [System.Drawing.Color]::White } else { $col.warn } }
    if ($it.Kind -eq 'all') { $fore = if ($sel) { [System.Drawing.Color]::White } else { $col.acc } }
    $brush = [System.Drawing.SolidBrush]::new($back)
    $e.Graphics.FillRectangle($brush, $e.Bounds)
    $brush.Dispose()
    if ($it.Kind -eq 'cron') {
        $pen = [System.Drawing.Pen]::new($col.bg3)
        $e.Graphics.DrawLine($pen, $e.Bounds.X + 6, $e.Bounds.Bottom - 2, $e.Bounds.Right - 6, $e.Bounds.Bottom - 2)
        $pen.Dispose()
    }
    $rf = [System.Drawing.RectangleF]::new([single]($e.Bounds.X + 8), [single]$e.Bounds.Y, [single]($e.Bounds.Width - 12), [single]$e.Bounds.Height)
    $f = if ($it.Kind -eq 'cat') { $font } else { $fontBold }
    $tb = [System.Drawing.SolidBrush]::new($fore)
    $e.Graphics.DrawString($it.Label, $f, $tb, $rf)
    $tb.Dispose()
    if ($it.Count -ge 0) {
        $sf = [System.Drawing.StringFormat]::new()
        $sf.Alignment = 'Far'; $sf.LineAlignment = 'Center'
        $numCol = if ($sel) { [System.Drawing.Color]::White } else { $col.mut }
        $cb2 = [System.Drawing.SolidBrush]::new($numCol)
        $e.Graphics.DrawString([string]$it.Count, $fontSmall, $cb2, $rf, $sf)
        $cb2.Dispose()
        $sf.Dispose()
    }
})
$lstCats.SelectedIndex = 1

# --- stato interno ---------------------------------------------------------
$script:Installed = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$script:Queue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
$script:Handle = $null; $script:Total = 0; $script:Done = 0
$script:Ok = 0; $script:Skip = 0; $script:Fail = 0; $script:Start = $null
$script:CurName = ''

function Update-SelCount {
    $n = 0
    foreach ($r in $script:Rows) { if ($r.cb.Checked) { $n++ } }
    $lblSelCount.Text = ("{0} selezionati" -f $n)
    $btnClear.Enabled = ($n -gt 0)
}
function Apply-Filter {
    $q = $txtSearch.Text.Trim().ToLower()
    $only = [bool]$chkOnly.Checked
    $cat = $script:ActiveCat
    $shown = 0
    # il layout di un FlowLayoutPanel con AutoScroll ricalcola tutto a ogni cambiamento di
    # Visible: sospenderlo durante il filtro e' cio' che tiene la UI reattiva con 200+ voci
    $flow.SuspendLayout()
    try {
        foreach ($h in $script:Heads) {
            $vis = 0
            foreach ($r in $h.rows) {
                $ok = $true
                if ($q) {
                    $hay = ([string]$r.pkg.name + ' ' + [string]$r.pkg.id + ' ' + [string]$r.pkg.desc).ToLower()
                    $ok = $hay.Contains($q)
                } elseif ($cat -ne '*' -and $h.cat -ne $cat) {
                    $ok = $false
                }
                if ($ok -and $only -and -not $r.cb.Checked) { $ok = $false }
                if ($r.cb.Visible -ne $ok) { $r.cb.Visible = $ok }
                if ($ok) { $vis++; $shown++ }
            }
            if ($h.lbl.Visible -ne ($vis -gt 0)) { $h.lbl.Visible = ($vis -gt 0) }
        }
    } finally { $flow.ResumeLayout($true) }
    if ($q) { $lblCatHead.Text = ("Risultati per '{0}'  ({1})" -f $txtSearch.Text.Trim(), $shown) }
    elseif ($cat -eq '*') { $lblCatHead.Text = ("Tutte le app  ({0})" -f $shown) }
    else { $lblCatHead.Text = ("{0}  ({1})" -f $cat, $shown) }
    Update-SelCount
}
function Show-Apps {
    $panelUpdates.Visible = $false
    $flow.Visible = $true
    $listHead.Visible = $true
}
function Show-Updates {
    $flow.Visible = $false
    $listHead.Visible = $false
    $panelUpdates.Visible = $true
    Refresh-Cron
}
function Apply-Preset([string]$name) {
    if ($name -eq 'none') {
        foreach ($r in $script:Rows) { $r.cb.Checked = $false }
        Apply-Filter
        return
    }
    $want = @(Get-Preset $name)
    foreach ($r in $script:Rows) {
        if ($want -notcontains $r.pkg.id) { $r.cb.Checked = $false; continue }
        if ($r.pkg.kind -eq 'pkg' -and $script:Installed.Contains($r.pkg.id) -and -not $chkForce.Checked) { $r.cb.Checked = $false; continue }
        $r.cb.Checked = $true
    }
    if ($txtSearch.Text) { $txtSearch.Text = '' }
    if ($lstCats.SelectedIndex -ne 1) { $lstCats.SelectedIndex = 1 } else { Show-Apps }
    Apply-Filter
}
function Write-Log([string]$m, $c = $null) {
    $log.SelectionStart = $log.TextLength; $log.SelectionLength = 0
    if ($c) { $log.SelectionColor = $c }
    $log.AppendText($m + "`r`n")
    $log.SelectionStart = $log.TextLength; $log.ScrollToCaret()
}
function Stamp { (Get-Date -Format 'HH:mm:ss') }

# --- cronjob: interfaccia nella sezione "Aggiornamenti automatici" ---------
function Refresh-Cron {
    $st = Get-CronStatus
    if ($st) {
        $next = ''
        try { $next = (Get-ScheduledTaskInfo -TaskName $TaskName).NextRunTime } catch {}
        $chkUpdOn.Checked = $true
        $lblUpdState.Text = ("Stato: ATTIVO. Task '{0}', prossima esecuzione: {1}" -f $TaskName, $next)
        $lblUpdState.ForeColor = $col.ok
    } else {
        $chkUpdOn.Checked = $false
        $lblUpdState.Text = 'Stato: non attivo. Nessun aggiornamento pianificato.'
        $lblUpdState.ForeColor = $col.mut
    }
    $numDays.Enabled = [bool]$chkUpdOn.Checked
    $dtpTime.Enabled = [bool]$chkUpdOn.Checked
    $chkElev.Enabled = [bool]$chkUpdOn.Checked
    $lblLogPath.Text = ('Log del task: ' + (Get-CronLogPath))
}
$btnUpdSave.Add_Click({
    try {
        if ($chkUpdOn.Checked) {
            $msg = Install-Cron -everyDays ([int]$numDays.Value) -at $dtpTime.Value.ToString('HH:mm') -elevated:$chkElev.Checked
        } else {
            $msg = Remove-Cron
        }
        Write-Log ("[{0}] {1}" -f (Stamp), $msg) $col.acc
        Refresh-Cron
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Aggiornamenti automatici', 'OK', 'Error') | Out-Null
    }
})
$btnUpdRun.Add_Click({
    try {
        if (Get-CronStatus) {
            Start-ScheduledTask -TaskName $TaskName
            Write-Log ("[{0}] Task '{1}' avviato adesso." -f (Stamp), $TaskName) $col.acc
        } else {
            if ([System.Windows.Forms.MessageBox]::Show('Nessun task pianificato. Eseguire winget upgrade --all adesso?', 'Conferma', 'YesNo') -ne 'Yes') { return }
            Show-Apps
            $lstCats.SelectedIndex = 1
            Start-Worker 'upgrade'
        }
        Refresh-Cron
    } catch {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Aggiornamenti automatici', 'OK', 'Error') | Out-Null
    }
})
$btnUpdRefresh.Add_Click({ Refresh-Cron })
$chkUpdOn.Add_CheckedChanged({
    $numDays.Enabled = [bool]$chkUpdOn.Checked
    $dtpTime.Enabled = [bool]$chkUpdOn.Checked
    $chkElev.Enabled = [bool]$chkUpdOn.Checked
})

# --- worker (runspace MTA) ------------------------------------------------
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
    $ids = @($script:Rows | Where-Object { $_.cb.Checked } | ForEach-Object { $_.pkg.id })
    $meta = @{}
    foreach ($r in $script:Rows) {
        $meta[$r.pkg.id] = @{ name = $r.pkg.name; src = $r.pkg.src; kind = $r.pkg.kind
            x = $r.pkg.x; y = $r.pkg.y; sens = $r.pkg.sens; speed = $r.pkg.speed; t1 = $r.pkg.t1; t2 = $r.pkg.t2 }
    }
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'MTA'; $rs.ThreadOptions = 'ReuseThread'; $rs.Open()
    $rs.SessionStateProxy.SetVariable('MsgQ', $script:Queue)
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    if ($kind -eq 'scan') {
        $allIds = @($script:Rows | Where-Object { $_.pkg.kind -eq 'pkg' } | ForEach-Object { $_.pkg.id })
        [void]$ps.AddScript($scanCore).AddArgument($script:Queue).AddArgument($allIds)
        $lblStatus.Text = 'Scansione dei pacchetti installati...'
    }
    else {
        $script:Total = $ids.Count; $script:Done = 0
        $script:Ok = 0; $script:Skip = 0; $script:Fail = 0; $script:Start = Get-Date
        $progress.Visible = $true
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
            'scan' { if ($msg.inst) { $null = $script:Installed.Add($msg.id) } }
            'scanDone' {
                $n = 0
                foreach ($r in $script:Rows) {
                    if ($r.pkg.kind -eq 'pkg' -and $script:Installed.Contains($r.pkg.id)) {
                        $r.cb.Text = ($r.base + '   (gia installato)')
                        $r.cb.ForeColor = $col.mut
                        $r.cb.Checked = $false
                        $n++
                    }
                }
                $applied = 0
                foreach ($r in $script:Rows) {
                    if ($r.pkg.kind -ne 'mouse' -or -not $r.pkg.x) { continue }
                    if ((Get-CurrentCurveHex 'SmoothMouseXCurve') -eq $r.pkg.x) {
                        $r.cb.Text = ($r.base + '   (gia applicato)')
                        $r.cb.ForeColor = $col.mut
                        $r.cb.Checked = $false
                        $applied++
                    }
                }
                $lblScan.Text = ("{0} installati - {1} mouse fix" -f $n, $applied)
                Write-Log ("[{0}] Scansione: {1} pacchetti installati, {2} fix mouse gia applicati. ItemsSize rilevato: {3}%." -f (Stamp), $n, $applied, (Get-CurrentScale)) $col.mut
                if ($Preset -ne 'none') { Apply-Preset $Preset } else { Apply-Filter }
                $lblStatus.Text = 'Pronto. Seleziona e premi APPLICA SELEZIONATI.'
            }
            'done' {
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

# --- eventi ---------------------------------------------------------------
$txtSearch.Add_TextChanged({ Apply-Filter })
$chkOnly.Add_CheckedChanged({ Apply-Filter })
$lstCats.Add_SelectedIndexChanged({
    try {
        $it = $lstCats.SelectedItem
        if (-not $it) { return }
        if ($it.Kind -eq 'cron') { Show-Updates; return }
        $script:ActiveCat = $it.Cat
        Show-Apps
        Apply-Filter
    } catch { }
})
$btnClear.Add_Click({
    foreach ($r in $script:Rows) { if ($r.cb.Checked) { $r.cb.Checked = $false } }
    if ($chkOnly.Checked) { $chkOnly.Checked = $false }
    Apply-Filter
})
$btnRec.Add_Click({ Apply-Preset 'recommended' })
$btnMine.Add_Click({ Apply-Preset 'mine' })
$btnExtra.Add_Click({ Apply-Preset 'extra' })
$btnMouseP.Add_Click({ Apply-Preset 'mouse' })
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
    foreach ($r in $script:Rows) {
        if ($chkForce.Checked -and $r.cb.Text -like '*(installato)*') { $r.cb.Checked = $true }
    }
    $sel = @($script:Rows | Where-Object { $_.cb.Checked })
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

$script:FlowWidth = 0
$flow.Add_Resize({
    $w = $flow.ClientSize.Width - 24
    if ($w -lt 240) { $w = 240 }
    if ($w -eq $script:FlowWidth) { return }
    $script:FlowWidth = $w
    foreach ($c in $flow.Controls) { if ($c.Width -ne $w) { $c.Width = $w } }
})

$form.Add_Shown({
    Write-Log ("[{0}] CHRK Installer v{1} - scala DPI rilevata: {2}%   |   (i preset sono nel rail: Consigliati / CHRK. / Extra / Mouse fix; 'Pulisci selezione' azzera le spunte)" -f (Stamp), $script:Version, (Get-CurrentScale)) $col.mut
    Refresh-Cron
    Apply-Filter
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
