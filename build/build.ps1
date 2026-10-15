<#
.SYNOPSIS
    Compila dist/CHRK-Installer.ps1 partendo dai dati in build/.

.DESCRIPTION
    Il file distribuito e' autocontenuto: questo script unisce
      - build/catalog-mine.json   (export winget -> app dell'autore, preset "Consigliati")
      - build/extras.json         (extra scelti a mano, stesso preset)      - build/mousefixes.inc      (fix mouse MarkC, gia' estratti)
      - build/assets/logo.png     (logo, embeddato in base64)
      - dati online: winstall.app/express (selezione curata + descrizioni)
                     e il catalogo applicazioni di WinUtil (nomi di riserva)
    dentro build/chrk-installer.template.ps1, producendo dist/CHRK-Installer.ps1.

    Non serve nessuna dipendenza locale oltre a PowerShell 5.1 e a internet.

.PARAMETER Version
    Versione da scrivere nell'artefatto. Se omessa, usa il file VERSION.

.PARAMETER UpdateUrl
    URL pubblico che lo script usera' per l'auto-aggiornamento.

.PARAMETER OutFile
    Percorso di output. Default: dist/CHRK-Installer.ps1

.EXAMPLE
    .\build\build.ps1
    .\build\build.ps1 -Version 1.1.0 -UpdateUrl 'https://s.chrk.tk'
#>
[CmdletBinding()]
param(
    [string]$Version,
    [string]$UpdateUrl = 'https://s.chrk.tk',
    [string]$OutFile
)

$ErrorActionPreference = 'Stop'
$buildDir = $PSScriptRoot
$repoDir  = Split-Path -Parent $buildDir
if (-not $OutFile) { $OutFile = Join-Path $repoDir 'dist\CHRK-Installer.ps1' }
$enc = [System.Text.UTF8Encoding]::new($false)

function Norm([string]$s) {
    if ($null -eq $s) { return '' }
    $t = $s -replace '\s+', ' '
    # i .ps1 vengono letti come ANSI da PowerShell 5.1: la stringa deve restare ASCII
    $t = $t.Replace([string][char]0x00AE, '(R)').Replace([string][char]0x2122, '(TM)').Replace([string][char]0x00A9, '(C)')
    $t = $t -replace '[^\x20-\x7E]', ''
    return $t.Trim()
}
function Get-Url([string]$u, [int]$tries = 4) {
    for ($i = 1; $i -le $tries; $i++) {
        try { return (Invoke-WebRequest $u -UseBasicParsing -TimeoutSec 45).Content }
        catch { if ($i -eq $tries) { throw }; Start-Sleep -Seconds (2 * $i) }
    }
}

if (-not $Version) {
    $vf = Join-Path $repoDir 'VERSION'
    $Version = if (Test-Path $vf) { (Get-Content $vf -Raw).Trim() } else { '0.0.0' }
}

# ---- 1) preset "CHRK." (i pacchetti dell'autore) --------------------------
$catalogMine = Join-Path $buildDir 'catalog-mine.json'
if (-not (Test-Path $catalogMine)) { throw "Manca $catalogMine" }
$exp  = Get-Content $catalogMine -Raw | ConvertFrom-Json
$mine = foreach ($s in $exp.Sources) { foreach ($p in $s.Packages) { [pscustomobject]@{ id = $p.PackageIdentifier; src = $s.SourceDetails.Name } } }
$mine = $mine | Sort-Object id -Unique

# ---- 2) extra attivati a mano --------------------------------------------
$extrasFile = Join-Path $buildDir 'extras.json'
$extras = if (Test-Path $extrasFile) { @(Get-Content $extrasFile -Raw | ConvertFrom-Json) } else { @() }

# ---- 3) winstall (selezione curata + descrizioni) -------------------------
$win = @{}
try {
    $html = Get-Url 'https://winstall.app/express'
    $m = [regex]::Match($html, '(?s)__NEXT_DATA__[^>]*>(.*?)</script>')
    if ($m.Success) {
        $j = $m.Groups[1].Value | ConvertFrom-Json
        foreach ($prop in $j.props.pageProps.categoryApps.PSObject.Properties) {
            foreach ($a in @($prop.Value)) {
                if (-not $a._id) { continue }
                $win[$a._id] = [pscustomobject]@{ name = Norm $a.name; desc = Norm $a.desc; pub = Norm $a.publisher }
            }
        }
    }
} catch { Write-Warning "winstall non raggiungibile: $_" }

# ---- 4) catalogo WinUtil (nomi/descrizioni di riserva) --------------------
$catMap = @{}
try {
    $apps = (Get-Url 'https://raw.githubusercontent.com/ChrisTitusTech/winutil/main/config/applications.json') | ConvertFrom-Json
    foreach ($p in $apps.PSObject.Properties) {
        $w = [string]$p.Value.winget
        if ($w -and $w -ne 'na') { $catMap[$w.ToLower()] = [pscustomobject]@{ name = Norm $p.Value.content; desc = Norm $p.Value.description } }
    }
} catch { Write-Warning "catalogo WinUtil non raggiungibile: $_" }

# ---- 5) nomi manuali ------------------------------------------------------
$nameMapFile = Join-Path $buildDir 'names.json'
$nameMap = @{}
if (Test-Path $nameMapFile) {
    $jn = Get-Content $nameMapFile -Raw | ConvertFrom-Json
    foreach ($p in $jn.PSObject.Properties) { $nameMap[$p.Name] = @{ name = $p.Value.name; desc = $p.Value.desc } }
}

# ---- 6) classificazione --------------------------------------------------
function Get-Cat([string]$id) {
    switch -Regex ($id) {
        '^(SteamDB|Valve|EpicGames|PrismLauncher|NexusMods|ebkr|HeroicGamesLauncher|Playnite|Modrinth|itch|GOG|Ubisoft|EA|Battle\.net|Cemu|EmulationStation|Overwolf|OuterWildsMods|PlayStation|Nvidia\.GeForce|ViGEm|namazso|PawnIO|ClassicOldSong|maximmax42|Datronicsoft|VirtualDesktop|RamenSoftware)(?:\.|$)' { return 'Gaming' }
        '^(Google\.Chrome|Mozilla\.Firefox|Brave|Vivaldi|Microsoft\.Edge|uazo\.cromite|Cromite|Waterfox|LibreWolf|ZenBrowser|Floorp|TorProject|Mullvad|Ungoogled|Chromium|Helium|Opera|TheBrowserCompany|Yandex)(?:\.|$)' { return 'Browser' }
        '^(Discord|Telegram|WhatsApp|Signal|SlackTechnologies|Slack|Zoom|Microsoft\.Teams|Microsoft\.Outlook|Mozilla\.Thunderbird|Thunderbird|Betterbird|Vencord|SpikeHD|Element|TeamSpeak|Proton\.ProtonMail|Viber|Matrix|Chatterino|qTox|Dorion|Revolt|Pidgin|CeruleanStudios|Cisco\.Webex)(?:\.|$)' { return 'Comunicazione' }
        '^(Nextcloud|Google\.GoogleDrive|Dropbox|Proton\.ProtonDrive|Syncthing|LocalSend|SSHFS-Win|WinFsp|Google\.ChromeRemoteDesktopHost|rclone|Mega|Microsoft\.OneDrive|Apple\.iCloud|qBittorrent|subhra74)(?:\.|$)' { return 'Cloud e rete' }
        '^(TeamViewer|AnyDesk|RustDesk|TightVNC|Parsec|Deskflow|PuTTY|Splashtop|Termius)(?:\.|$)' { return 'Remoto e supporto' }
        '^(Bitwarden|KeePassXC|Proton\.ProtonPass|AgileBits|1Password|Malwarebytes|simplewall|WireGuard|OpenVPN|Mullvad|Tailscale|Cloudflare\.CloudflareWARP|Nmap|Wireshark|GnuPG|Cryptomator|VeraCrypt|NordVPN|ExpressVPN|Surfshark|Windscribe|KeeperSecurity|LastPass|ESET)(?:\.|$)' { return 'Sicurezza e VPN' }
        '^(SumatraPDF|PDF24|geeksoftwareGmbH|PDF-XChange|Foxit|Adobe\.Acrobat|AcroSoftware|LibreOffice|TheDocumentFoundation|ONLYOFFICE|Kingsoft|Microsoft\.Office|Obsidian|Joplin|Evernote|Notion|Zotero|NAPS2|Xournal|PDFgear|PDFsam|QOwnNotes|Simplenote|Apache\.OpenOffice|Calibre|Xmind)(?:\.|$)' { return 'Documenti' }
        '^(VideoLAN|Daum|HandBrake|Gyan\.FFmpeg|yt-dlp|OBSProject|shinchiro|mpv|ShareX|Greenshot|TenacityTeam|Audacity|GIMP|dotPDN|KDE|Krita|BlenderFoundation|Blender|Canva|ImageGlass|IrfanSkiljan|IrfanView|FastStone|XnSoft|EarTrumpet|K-Lite|CodecGuide|mpc-qt|AIMP|foobar|jeffvli|VictorAlves|Spotify|Apple\.iTunes|iTunes|AdrienAllard|OpenShot|Shotcut|nomacs|jpegview|Upscayl|Stremio|Inkscape|ByteDance|Google\.EarthPro)(?:\.|$)' { return 'Multimedia e foto' }
        '^(Microsoft\.VisualStudioCode|Microsoft\.VisualStudio|Microsoft\.WindowsTerminal|Microsoft\.PowerShell|Git|GitHub|GitExtensions|Kitware|OpenJS|GoLang|Python|Rustlang|DenoLand|astral-sh|EclipseAdoptium|Oracle|Amazon\.Corretto|Google\.AndroidStudio|Google\.PlatformTools|ArduinoSA|StrawberryPerl|Ninja-build|SST\.opencode|Anthropic|Ollama|JetBrains|Postman|Bruno|Docker|Zed|Neovim|Lazygit|Starship|JanDeDobbeleer|pnpm|PNPM|Yarn|CoreyButler|SystemInformer|SublimeText|Unity|Vagrant|Hashicorp|Qt|LLVM|RubyLang|Lua|Anysphere|Notepad\+\+|WinMerge|Ngrok)(?:\.|$)' { return 'Sviluppo' }
        '^(7zip|NanaZip|M2Team|WinRAR|rarlab|PeaZip|Bandizip|Corel\.WinZip|Everything|voidtools|WizTree|AntibodySoftware|WinDirStat|TreeSize|HxD|xeheditor)(?:\.|$)' { return 'File e archivi' }
        '^(RamenSoftware|StartIsBack|Nilesoft|rcmaehl|tchumakov|OFGB|Microsoft\.PowerToys|PowerToys|AutoHotkey|GlazeWM|glazewm|ProcessLasso|processlasso|StefanSundin|Devolutions|UniGetUI|Klocman|Revo|WiseCleaner|PolicyPlus|policyplus|TranslucentTB|ttaskbar|Winaero|infinitepower18)(?:\.|$)' { return 'Sistema e tweaks' }
        '^(CPUID|TechPowerUp|HWiNFO|hwmonitor|CrystalDewWorld|Guru3D|MSI|OpenRGB|SignalRGB|nvclean|DisplayDriverUninstaller|Corsair|Razer|Logitech|FanControl|ArgusMonitor|Bambulab|Prusa|Ultimaker|OrcaSlicer|9N1KVPCJP303|XP89DCGQ3K6VLD)(?:\.|$)' { return 'Hardware e monitoraggio' }
        '^(Rufus|Ventoy|Balena|Fedora|UNetbootin|Win32DiskImager)(?:\.|$)' { return 'USB e masterizzazione' }
        '^(Microsoft\.VCRedist|Microsoft\.DotNet|Microsoft\.NET|Microsoft\.VCLibs|Microsoft\.WindowsAppRuntime|Microsoft\.UI\.Xaml|Microsoft\.DirectX|Microsoft\.GameInput|Microsoft\.AppInstaller|Microsoft\.Xaml|Nvidia\.PhysX|Microsoft\.WindowsDesktop|Microsoft\.EdgeWebView)(?:\.|$)' { return 'Runtime e librerie' }
    }
    return 'Altre app'
}

# ---- 7) costruzione voci -------------------------------------------------
$all = @{}
function Add-Entry([string]$id, [string]$preset, [string]$src) {
    if ([string]::IsNullOrWhiteSpace($id)) { return }
    $key = $id.ToLower()
    $name = $null; $desc = ''; $pub = ''
    if ($win.ContainsKey($id)) { $name = $win[$id].name; $desc = $win[$id].desc; $pub = $win[$id].pub }
    if (-not $name -and $catMap.ContainsKey($key)) { $name = $catMap[$key].name; if (-not $desc) { $desc = $catMap[$key].desc } }
    if ($nameMap.ContainsKey($key)) { if (-not $name) { $name = $nameMap[$key].name }; if (-not $desc) { $desc = $nameMap[$key].desc } }
    if (-not $name) { $parts = $id -split '\.'; $name = if ($parts.Count -gt 1) { ($parts | Select-Object -Skip 1) -join ' ' } else { $id } }
    if ($desc.Length -gt 220) { $desc = $desc.Substring(0, 217) + '...' }
    $prev = $all[$key]
    if ($prev) {
        if ($preset -and -not $prev.preset) { $prev.preset = $preset }
        if (-not $prev.desc -and $desc) { $prev.desc = $desc }
        if (-not $prev.pub -and $pub) { $prev.pub = $pub }
        return
    }
    $all[$key] = [pscustomobject]@{ id = $id; name = $name; cat = (Get-Cat $id); desc = $desc; pub = $pub; src = $src; preset = $preset }
}
foreach ($m in $mine)   { Add-Entry $m.id $(if ($extras -contains $m.id) { 'extra' } else { 'mine' }) $m.src }
foreach ($e in $extras) { Add-Entry $e 'extra' 'winget' }
foreach ($id in $win.Keys) { Add-Entry $id '' 'winget' }

# ---- 8) emissione --------------------------------------------------------
$catOrder = @('Browser','Comunicazione','Documenti','Sviluppo','Multimedia e foto','Gaming','Cloud e rete','Sicurezza e VPN',
              'Sistema e tweaks','File e archivi','Hardware e monitoraggio','USB e masterizzazione','Remoto e supporto',
              'Altre app','Mouse','Runtime e librerie')
$rank = @{ 'mine' = 0; 'extra' = 1; '' = 2 }

$lines = [System.Collections.Generic.List[string]]::new()
foreach ($it in ($all.Values | Sort-Object @{e={$catOrder.IndexOf($_.cat)}}, @{e={$rank[$_.preset]}}, name)) {
    $n = $it.name.Replace("'", "''"); $d = $it.desc.Replace("'", "''"); $p = $it.pub.Replace("'", "''")
    $lines.Add(("    @{{ id = '{0}'; name = '{1}'; cat = '{2}'; desc = '{3}'; pub = '{4}'; src = '{5}'; preset = '{6}'; kind = 'pkg' }}" -f `
        $it.id, $n, $it.cat, $d, $p, $it.src, $it.preset))
}
$inc = Join-Path $buildDir 'mousefixes.inc'
if (Test-Path $inc) { $lines.AddRange([string[]](Get-Content $inc)) }
$body = ($lines -join ",`r`n")

# ---- 9) logo + template --------------------------------------------------
$logoPath = Join-Path $buildDir 'assets\logo.png'
if (-not (Test-Path $logoPath)) { throw "logo non trovato: $logoPath" }
$logoB64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($logoPath))

$tpl = [System.IO.File]::ReadAllText((Join-Path $buildDir 'chrk-installer.template.ps1'), $enc)
foreach ($ph in @('__PACKAGES__', '__LOGO_B64__', '__VERSION__', '__UPDATE_URL__')) {
    if ($tpl -notmatch $ph) { throw "placeholder $ph non trovato nel template" }
}
$out = $tpl.Replace('__PACKAGES__', $body).Replace('__LOGO_B64__', $logoB64).
    Replace('__VERSION__', $Version).Replace('__UPDATE_URL__', $UpdateUrl)

$outDir = Split-Path -Parent $OutFile
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
[System.IO.File]::WriteAllText($OutFile, $out, $enc)

# ---- 9b) controllo finale: l'artefatto deve essere ASCII puro --------------
$badChars = @($out.ToCharArray() | Where-Object { [int]$_ -gt 127 })
if ($badChars.Count) {
    $codes = (($badChars | ForEach-Object { 'U+{0:X4}' -f [int]$_ } | Select-Object -Unique) -join ' ')
    throw ("L artefatto contiene {0} caratteri non-ASCII ({1}): sanifica i dati in build/." -f $badChars.Count, $codes)
}

# ---- 10) resoconto -------------------------------------------------------
Write-Host ""
Write-Host ("CHRK-Installer v{0}" -f $Version) -ForegroundColor Cyan
Write-Host ("  output    : {0}  ({1} KB)" -f $OutFile, [math]::Round((Get-Item $OutFile).Length / 1KB, 1))
Write-Host ("  update url: {0}" -f $UpdateUrl)
Write-Host ("  voci      : {0}  (winstall: {1}, WinUtil: {2})" -f $lines.Count, $win.Count, $catMap.Count)
Write-Host ""
foreach ($g in ($all.Values | Group-Object cat | Sort-Object { $catOrder.IndexOf($_.Name) })) {
    Write-Host ("  {0,-24} {1}" -f $g.Name, $g.Count)
}
Write-Host ""
Write-Host ("  consigliate: {0} app mie + {1} extra  |  popolari: {2}" -f `
    @($all.Values | Where-Object preset -eq 'mine').Count, `
    @($all.Values | Where-Object preset -eq 'extra').Count, `
    @($all.Values | Where-Object { -not $_.preset }).Count)
Write-Host ("  con descrizione: {0}/{1}" -f @($all.Values | Where-Object { $_.desc }).Count, $all.Count)
if ($win.Count -eq 0) { Write-Warning "winstall non ha risposto: il catalogo e' incompleto, NON pubblicare questo build." }
$altro = @($all.Values | Where-Object { $_.cat -eq 'Altre app' })
if ($altro.Count) { Write-Warning ("voci non classificate ({0}): {1}" -f $altro.Count, (($altro | Select-Object -ExpandProperty id) -join ', ')) }
Write-Host ""
