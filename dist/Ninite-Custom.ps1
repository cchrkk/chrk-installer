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
$script:Version   = '1.0.0'
$script:UpdateUrl = 'https://s.chrk.tk'

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
    @{ id = 'Microsoft.Edge'; name = 'Microsoft Edge'; cat = 'Browser'; desc = 'Microsoft Edge is a cross-platform web browser built for modern life.'; pub = 'Microsoft Corporation'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'TheBrowserCompany.Arc'; name = 'Arc'; cat = 'Browser'; desc = 'Arc is a new browser that shapes itself to how you use the internet. It offers Spaces, Profiles, Split View, Themes, and more to organize and customize your online experience.'; pub = 'The Browser Company of New York'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Brave.Brave'; name = 'Brave'; cat = 'Browser'; desc = 'Secure, Fast & Private Web Browser with Adblocker'; pub = 'Brave Software Inc'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Google.Chrome'; name = 'Google Chrome'; cat = 'Browser'; desc = 'The Fast & Secure Web Browser Built to be Yours'; pub = 'Google LLC'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Mozilla.Firefox'; name = 'Mozilla Firefox (en-US)'; cat = 'Browser'; desc = 'Mozilla Firefox is free and open source software, built by a community of thousands from all over the world.'; pub = 'Mozilla'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Mozilla.Firefox.ESR'; name = 'Mozilla Firefox ESR (en-US)'; cat = 'Browser'; desc = 'Get the Firefox Extended Support Release or Rapid Release browser for comprehensive data security and data protection.'; pub = 'Mozilla'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Opera.Opera'; name = 'Opera Stable'; cat = 'Browser'; desc = 'The Opera browser includes everything you need for private, safe, and efficient browsing, along with a variety of unique features to enhance your capabilities online.'; pub = 'Opera Software'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Vivaldi.Vivaldi'; name = 'Vivaldi'; cat = 'Browser'; desc = 'Powerful, Personal and Private web browser.'; pub = 'Vivaldi Technologies AS.'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Yandex.Browser'; name = 'Yandex Browser'; cat = 'Browser'; desc = 'Yandex Browser delivers fast and secure browsing with built-in Alice and the ability to sync passwords, bookmarks, and bank cards across devices.'; pub = 'Yandex'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'SpikeHD.Dorion'; name = 'Dorion'; cat = 'Comunicazione'; desc = 'Tiny alternative Discord client with a smaller footprint, snappier startup, themes, plugins and more!'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.Teams'; name = 'Microsoft Teams'; cat = 'Comunicazione'; desc = 'Collaborate more effectively with a faster, simpler, smarter, and more flexible Teams.'; pub = 'Microsoft Corporation'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.Outlook'; name = 'Outlook'; cat = 'Comunicazione'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Telegram.TelegramDesktop'; name = 'Telegram Desktop'; cat = 'Comunicazione'; desc = 'A cloud-based mobile and desktop messaging app with a focus on security and speed.'; pub = 'Telegram FZ-LLC'; src = 'winget'; preset = 'extra'; kind = 'pkg' },
    @{ id = 'Vencord.Vesktop'; name = 'Vesktop'; cat = 'Comunicazione'; desc = 'A cross-platform electron-based desktop app aiming to give you a snappier Discord experience with Vencord pre-installed.'; pub = ''; src = 'winget'; preset = 'extra'; kind = 'pkg' },
    @{ id = 'Discord.Discord.x86'; name = 'Discord (x86)'; cat = 'Comunicazione'; desc = 'Your Place to Talk and Hang Out.'; pub = 'Discord Inc.'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Microsoft.Office'; name = 'Microsoft 365 Apps for enterprise'; cat = 'Comunicazione'; desc = 'The most productive and most secure Office experience for enterprises, allowing your teams to work together seamlessly from anywhere, anytime.'; pub = 'Microsoft Corporation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Mozilla.Thunderbird'; name = 'Mozilla Thunderbird (en-US)'; cat = 'Comunicazione'; desc = 'Thunderbird is a free email application that is easy to set up and customize - and it''s loaded with great features!'; pub = 'Mozilla'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Mozilla.Thunderbird.ESR'; name = 'Mozilla Thunderbird ESR (en-US)'; cat = 'Comunicazione'; desc = 'The official annual extended support release of Thunderbird intended for users who want all available new features on an annual basis and stability/security fixes on a monthly basis.'; pub = 'Mozilla'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Pidgin.Pidgin'; name = 'Pidgin'; cat = 'Comunicazione'; desc = 'Pidgin is a universal chat client, allowing you to consolidate all your different messaging apps into a single tool.'; pub = 'Pidgin IM'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'SlackTechnologies.Slack'; name = 'Slack'; cat = 'Comunicazione'; desc = 'Slack brings the team together, wherever you are.'; pub = 'Slack Technologies Inc.'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'CeruleanStudios.Trillian'; name = 'Trillian'; cat = 'Comunicazione'; desc = 'A modern and secure instant messaging for people, business and healthcare'; pub = 'Cerulean Studios, LLC'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Cisco.Webex'; name = 'Webex'; cat = 'Comunicazione'; desc = 'With industry leading video conferencing, calling, and contact center solutions, Webex fuels hybrid work for businesses of all sizes.'; pub = 'Cisco Systems, Inc'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Zoom.Zoom'; name = 'Zoom Workplace'; cat = 'Comunicazione'; desc = 'Team Chat, Phone, Video & More'; pub = 'Zoom'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Apache.OpenOffice'; name = 'OpenOffice'; cat = 'Documenti'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'geeksoftwareGmbH.PDF24Creator'; name = 'PDF24 Creator'; cat = 'Documenti'; desc = 'Free and easy-to-use online/desktop PDF tools that make you more productive'; pub = ''; src = 'winget'; preset = 'extra'; kind = 'pkg' },
    @{ id = 'Adobe.Acrobat.Reader.64-bit'; name = 'Adobe Acrobat Reader (64-bit)'; cat = 'Documenti'; desc = 'The free global standard for reliably viewing, printing, signing, and commenting on PDF documents.'; pub = 'Adobe'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'AcroSoftware.CutePDFWriter'; name = 'CutePDF Writer'; cat = 'Documenti'; desc = 'Create PDFs from almost any application'; pub = 'Acro Software Inc.'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Evernote.Evernote'; name = 'Evernote'; cat = 'Documenti'; desc = 'Remember everything and tackle any project with your notes, tasks, and schedule all in one place.'; pub = 'Evernote Corporation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Foxit.FoxitReader.Inno'; name = 'Foxit PDF Reader'; cat = 'Documenti'; desc = 'Industrys most powerful PDF Reader Solution.'; pub = 'Foxit Software Inc.'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'TheDocumentFoundation.LibreOffice'; name = 'LibreOffice'; cat = 'Documenti'; desc = 'LibreOffice is a free and powerful office suite, and a successor to OpenOffice.org (commonly known as OpenOffice). Its clean interface and feature-rich tools help you unleash your creativity and enhance your productiv...'; pub = 'The Document Foundation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Notion.Notion'; name = 'Notion'; cat = 'Documenti'; desc = 'A new tool that blends your everyday work apps into one. It''s the all-in-one workspace for you and your team.'; pub = 'Notion Labs, Inc'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Kingsoft.WPSOffice'; name = 'WPS Office'; cat = 'Documenti'; desc = 'A free office suite fully compatible with Microsoft Office'; pub = 'Kingsoft Corp.'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Xmind.Xmind'; name = 'Xmind'; cat = 'Documenti'; desc = 'A full-featured Swiss Army Knife for your brain.'; pub = 'XMIND LTD.'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Google.AndroidStudio'; name = 'AndroidStudio'; cat = 'Sviluppo'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Anthropic.Claude'; name = 'Claude Desktop'; cat = 'Sviluppo'; desc = 'Anthropic''s Claude desktop application for focused AI-assisted work and chat.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Kitware.CMake'; name = 'CMake'; cat = 'Sviluppo'; desc = 'CMake is an open-source, cross-platform family of tools designed to build, test and package software.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'DenoLand.Deno'; name = 'Deno'; cat = 'Sviluppo'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'EclipseAdoptium.Temurin.17.JDK'; name = 'Eclipse Temurin JDK with Hotspot 17'; cat = 'Sviluppo'; desc = 'Eclipse Temurin JDK is the open source Java SE build based upon OpenJDK.'; pub = 'Eclipse Adoptium'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Git.Git'; name = 'Git'; cat = 'Sviluppo'; desc = 'A free and open source distributed version control system'; pub = 'The Git Development Community'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'GitHub.cli'; name = 'GitHub CLI'; cat = 'Sviluppo'; desc = 'GitHub CLI brings pull requests, issues, releases, and other GitHub workflows to the terminal.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'GoLang.Go'; name = 'Go'; cat = 'Sviluppo'; desc = 'Go (or Golang) is a statically typed, compiled programming language designed for simplicity, reliability, and efficiency.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'ArduinoSA.IDE.stable'; name = 'IDE stable'; cat = 'Sviluppo'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Oracle.JavaRuntimeEnvironment'; name = 'Java 8'; cat = 'Sviluppo'; desc = 'Java allows you to play online games, chat with people around the world, calculate your mortgage interest, and view images in 3D, just to name a few.'; pub = 'Oracle Corporation'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Python.Launcher'; name = 'Launcher'; cat = 'Sviluppo'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Ninja-build.Ninja'; name = 'Ninja'; cat = 'Sviluppo'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'OpenJS.NodeJS'; name = 'NodeJS'; cat = 'Sviluppo'; desc = 'NodeJS is a JavaScript runtime built on Chrome''s V8 JavaScript engine for building server-side and networking applications.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Notepad++.Notepad++'; name = 'Notepad++'; cat = 'Sviluppo'; desc = 'Notepad++ is a free source code editor that supports several languages.'; pub = 'Notepad++ Team'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Ollama.Ollama'; name = 'Ollama'; cat = 'Sviluppo'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'SST.opencode'; name = 'opencode'; cat = 'Sviluppo'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Google.PlatformTools'; name = 'PlatformTools'; cat = 'Sviluppo'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.PowerShell'; name = 'PowerShell'; cat = 'Sviluppo'; desc = 'PowerShell is a task automation framework and scripting language designed for system administrators, offering powerful command-line capabilities.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Python.Python.3.14'; name = 'Python 3.14'; cat = 'Sviluppo'; desc = 'A programming language that lets you work more quickly and integrate your systems more effectively.'; pub = 'Python Software Foundation'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Rustlang.Rustup'; name = 'Rustup'; cat = 'Sviluppo'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'StrawberryPerl.StrawberryPerl'; name = 'StrawberryPerl'; cat = 'Sviluppo'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'astral-sh.uv'; name = 'uv'; cat = 'Sviluppo'; desc = 'uv is a fast Python package and project manager written in Rust.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.VisualStudio.2022.Community'; name = 'Visual Studio 2022'; cat = 'Sviluppo'; desc = 'Visual Studio 2022 is an integrated development environment (IDE) for building, debugging, and deploying applications.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.WindowsTerminal'; name = 'Windows Terminal'; cat = 'Sviluppo'; desc = 'Windows Terminal is a modern, fast, and efficient terminal application for command-line users, supporting multiple tabs, panes, and more.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.VisualStudioCode'; name = 'Microsoft Visual Studio Code'; cat = 'Sviluppo'; desc = 'Microsoft Visual Studio Code is a code editor redefined and optimized for building and debugging modern web and cloud applications. Microsoft Visual Studio Code is free and available on your favorite platform - Linux,...'; pub = 'Microsoft Corporation'; src = 'winget'; preset = 'extra'; kind = 'pkg' },
    @{ id = 'Amazon.Corretto.11.JDK'; name = 'Amazon Corretto 11'; cat = 'Sviluppo'; desc = 'Amazon Corretto 11 is a Long-Term Supported (LTS) distribution of OpenJDK 11'; pub = 'Amazon'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Amazon.Corretto.17.JDK'; name = 'Amazon Corretto 17'; cat = 'Sviluppo'; desc = 'Amazon Corretto 17 is a Long-Term Supported (LTS) distribution of OpenJDK 17'; pub = 'Amazon'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Amazon.Corretto.21.JDK'; name = 'Amazon Corretto 21'; cat = 'Sviluppo'; desc = 'Amazon Corretto 21 is a Long-Term Supported (LTS) distribution of OpenJDK 21'; pub = 'Amazon'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Amazon.Corretto.25.JDK'; name = 'Amazon Corretto 25'; cat = 'Sviluppo'; desc = 'Amazon Corretto 25 is a distribution of OpenJDK 25'; pub = 'Amazon'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Amazon.Corretto.8.JDK'; name = 'Amazon Corretto 8'; cat = 'Sviluppo'; desc = 'Amazon Corretto 8 is a Long-Term Supported (LTS) distribution of OpenJDK 8'; pub = 'Amazon'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Amazon.Corretto.8.JRE'; name = 'Amazon Corretto JRE 8'; cat = 'Sviluppo'; desc = 'Amazon Corretto JRE 8 is a Long-Term Supported (LTS) distribution of OpenJRE 8'; pub = 'Amazon'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Anysphere.Cursor'; name = 'Cursor'; cat = 'Sviluppo'; desc = 'The AI Code Editor'; pub = 'Anysphere'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Docker.DockerDesktop'; name = 'Docker Desktop'; cat = 'Sviluppo'; desc = 'An application for the building and sharing of containerized applications.'; pub = 'Docker Inc.'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'EclipseAdoptium.Temurin.11.JDK'; name = 'Eclipse Temurin JDK with Hotspot 11'; cat = 'Sviluppo'; desc = 'Eclipse Temurin JDK is the open source Java SE build based upon OpenJDK.'; pub = 'Eclipse Adoptium'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'EclipseAdoptium.Temurin.21.JDK'; name = 'Eclipse Temurin JDK with Hotspot 21'; cat = 'Sviluppo'; desc = 'Eclipse Temurin JDK is the open source Java SE build based upon OpenJDK.'; pub = 'Eclipse Adoptium'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'EclipseAdoptium.Temurin.25.JDK'; name = 'Eclipse Temurin JDK with Hotspot 25'; cat = 'Sviluppo'; desc = 'Eclipse Temurin JDK is the open source Java SE build based upon OpenJDK.'; pub = 'Eclipse Adoptium'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'EclipseAdoptium.Temurin.8.JDK'; name = 'Eclipse Temurin JDK with Hotspot 8'; cat = 'Sviluppo'; desc = 'Eclipse Temurin JDK is the open source Java SE build based upon OpenJDK.'; pub = 'Eclipse Adoptium'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'EclipseAdoptium.Temurin.11.JRE'; name = 'Eclipse Temurin JRE with Hotspot 11'; cat = 'Sviluppo'; desc = 'Eclipse Temurin JRE is the open source Java SE build based upon OpenJRE.'; pub = 'Eclipse Adoptium'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'EclipseAdoptium.Temurin.17.JRE'; name = 'Eclipse Temurin JRE with Hotspot 17'; cat = 'Sviluppo'; desc = 'Eclipse Temurin JRE is the open source Java SE build based upon OpenJRE.'; pub = 'Eclipse Adoptium'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'EclipseAdoptium.Temurin.21.JRE'; name = 'Eclipse Temurin JRE with Hotspot 21'; cat = 'Sviluppo'; desc = 'Eclipse Temurin JRE is the open source Java SE build based upon OpenJRE.'; pub = 'Eclipse Adoptium'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'EclipseAdoptium.Temurin.25.JRE'; name = 'Eclipse Temurin JRE with Hotspot 25'; cat = 'Sviluppo'; desc = 'Eclipse Temurin JRE is the open source Java SE build based upon OpenJRE.'; pub = 'Eclipse Adoptium'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'EclipseAdoptium.Temurin.8.JRE'; name = 'Eclipse Temurin JRE with Hotspot 8'; cat = 'Sviluppo'; desc = 'Eclipse Temurin JRE is the open source Java SE build based upon OpenJRE.'; pub = 'Eclipse Adoptium'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Oracle.JDK.17'; name = 'Java(TM) SE Development Kit 17'; cat = 'Sviluppo'; desc = 'The JDK is a development environment for building applications and components using the Java programming language.'; pub = 'Oracle Corporation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Oracle.JDK.21'; name = 'Java(TM) SE Development Kit 21'; cat = 'Sviluppo'; desc = 'The JDK is a development environment for building applications and components using the Java programming language.'; pub = 'Oracle Corporation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Oracle.JDK.25'; name = 'Java(TM) SE Development Kit 25'; cat = 'Sviluppo'; desc = 'The JDK is a development environment for building applications and components using the Java programming language.'; pub = 'Oracle Corporation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Ngrok.Ngrok'; name = 'Ngrok'; cat = 'Sviluppo'; desc = 'Tunnel local ports to public URLs and inspect traffic'; pub = 'ngrok, Inc.'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Python.Python.3.13'; name = 'Python 3.13'; cat = 'Sviluppo'; desc = 'Python is a programming language that lets you work more quickly and integrate your systems more effectively.'; pub = 'Python Software Foundation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Python.PythonInstallManager'; name = 'Python Install Manager'; cat = 'Sviluppo'; desc = 'Install, manage, and launch Python on Windows.'; pub = 'Python Software Foundation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'WinMerge.WinMerge'; name = 'WinMerge'; cat = 'Sviluppo'; desc = 'WinMerge is an open source differencing and merging tool for Windows.'; pub = 'Thingamahoochie Software'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Canva.Affinity'; name = 'Affinity'; cat = 'Multimedia e foto'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'VictorAlves.Aonsoku'; name = 'Aonsoku'; cat = 'Multimedia e foto'; desc = 'Client desktop per server musicali Subsonic.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'jeffvli.Feishin'; name = 'Feishin'; cat = 'Multimedia e foto'; desc = 'Player musicale per server Navidrome/Jellyfin/Subsonic.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'yt-dlp.FFmpeg'; name = 'FFmpeg'; cat = 'Multimedia e foto'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Gyan.FFmpeg'; name = 'FFmpeg'; cat = 'Multimedia e foto'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'HandBrake.HandBrake'; name = 'HandBrake'; cat = 'Multimedia e foto'; desc = 'HandBrake is an open-source video transcoder, allowing you to convert video from nearly any format to a selection of widely supported codecs.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Daum.PotPlayer'; name = 'PotPlayer'; cat = 'Multimedia e foto'; desc = 'Powerful multimedia player that supports a variety of different video codecs and formats.'; pub = 'Kakao Corp.'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'ShareX.ShareX'; name = 'ShareX'; cat = 'Multimedia e foto'; desc = 'Screen capture, file sharing and productivity tool'; pub = 'ShareX Team'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Spotify.Spotify'; name = 'Spotify'; cat = 'Multimedia e foto'; desc = 'All the music youll ever need.'; pub = 'Spotify AB'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'TenacityTeam.Tenacity'; name = 'Tenacity'; cat = 'Multimedia e foto'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'VideoLAN.VLC'; name = 'VLC media player'; cat = 'Multimedia e foto'; desc = 'VLC is a free and open source cross-platform multimedia player and framework that plays most multimedia files, and various streaming protocols.'; pub = 'VideoLAN'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'yt-dlp.yt-dlp'; name = 'yt-dlp'; cat = 'Multimedia e foto'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'AdrienAllard.FileConverter'; name = 'File Converter'; cat = 'Multimedia e foto'; desc = 'File Converter converts and compresses files from the Windows Explorer context menu.'; pub = ''; src = 'winget'; preset = 'extra'; kind = 'pkg' },
    @{ id = 'shinchiro.mpv'; name = 'mpv'; cat = 'Multimedia e foto'; desc = 'mpv is a free, open source, and cross-platform media player supporting a wide variety of media formats, codecs, and subtitle types.'; pub = ''; src = 'winget'; preset = 'extra'; kind = 'pkg' },
    @{ id = 'OBSProject.OBSStudio'; name = 'OBS Studio'; cat = 'Multimedia e foto'; desc = 'Free and open source software for video recording and live streaming.'; pub = 'OBS Project'; src = 'winget'; preset = 'extra'; kind = 'pkg' },
    @{ id = 'BlenderFoundation.Blender'; name = 'blender'; cat = 'Multimedia e foto'; desc = 'Free and Open 3D Creation Software'; pub = 'Blender Foundation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'ByteDance.CapCut'; name = 'CapCut'; cat = 'Multimedia e foto'; desc = 'A video editing tool packed with features on your desktop or laptop'; pub = 'Bytedance Pte. Ltd.'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'FastStone.Viewer'; name = 'FastStone Image Viewer'; cat = 'Multimedia e foto'; desc = 'FastStone Image Viewer is a fast, stable, user-friendly image browser, converter and editor.'; pub = 'FastStone Corporation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'GIMP.GIMP.3'; name = 'GIMP'; cat = 'Multimedia e foto'; desc = 'GIMP is an acronym for GNU Image Manipulation Program. It is a freely distributed program for such tasks as photo retouching, image composition and image authoring.'; pub = 'The GIMP Team'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Google.EarthPro'; name = 'Google Earth Pro'; cat = 'Multimedia e foto'; desc = 'The world''s most detailed globe'; pub = 'Google'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Greenshot.Greenshot'; name = 'Greenshot'; cat = 'Multimedia e foto'; desc = 'A light-weight screenshot software tool for Windows.'; pub = 'Greenshot'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Inkscape.Inkscape'; name = 'Inkscape'; cat = 'Multimedia e foto'; desc = 'A professional vector graphics software which runs on Linux, macOS and Windows desktop computers.'; pub = 'Inkscape'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'IrfanSkiljan.IrfanView'; name = 'IrfanView'; cat = 'Multimedia e foto'; desc = 'Fast and compact image viewer and converter'; pub = 'Irfan Skiljan'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Apple.iTunes'; name = 'iTunes'; cat = 'Multimedia e foto'; desc = 'iTunes offers the worlds best way to play  and add to  your collection of music, movies, TV shows, podcasts, audiobooks, and more.'; pub = 'Apple Inc.'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'KDE.Krita'; name = 'Krita'; cat = 'Multimedia e foto'; desc = 'Krita is a professional FREE and open source painting program. It is made by artists that want to see affordable art tools for everyone.'; pub = 'Krita Foundation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'dotPDN.PaintDotNet'; name = 'paint.net'; cat = 'Multimedia e foto'; desc = 'An image and photo editing software for PCs that run Windows.'; pub = 'dotPDN LLC'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'XnSoft.XnView.Classic'; name = 'XnView'; cat = 'Multimedia e foto'; desc = 'Best Photo Viewer, Image Resizer & Batch Converter for Windows.'; pub = 'Gougelet Pierre-e'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'ClassicOldSong.Apollo'; name = 'Apollo'; cat = 'Gaming'; desc = 'Server di game streaming (fork di Sunshine) per Moonlight.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'maximmax42.CustomRP'; name = 'CustomRP'; cat = 'Gaming'; desc = 'Presenze Discord personalizzate.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'EpicGames.EpicGamesLauncher'; name = 'Epic Games Launcher'; cat = 'Gaming'; desc = 'Epic Games Launcher for the Epic Games Store and Unreal Engine'; pub = 'Epic Games, Inc.'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'EpicGames.EpicOnlineServices'; name = 'Epic Online Services'; cat = 'Gaming'; desc = 'Servizi online usati da alcuni giochi Epic.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'OuterWildsMods.OuterWildsModManager'; name = 'Outer Wilds Mod Manager'; cat = 'Gaming'; desc = 'Gestore mod per Outer Wilds.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'namazso.PawnIO'; name = 'PawnIO'; cat = 'Gaming'; desc = 'Driver kernel per accesso hardware a basso livello.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'PlayStation.PlayStationAccessories'; name = 'PlayStation Accessories'; cat = 'Gaming'; desc = 'Gestione accessori e controller PlayStation.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'PrismLauncher.PrismLauncher'; name = 'Prism Launcher'; cat = 'Gaming'; desc = 'Prism Launcher is an open-source Minecraft launcher with the ability to manage multiple instances, accounts, and mods.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'ebkr.r2modman'; name = 'r2modman'; cat = 'Gaming'; desc = 'Gestore mod per giochi Unity (Risk of Rain 2 e altri).'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Datronicsoft.SpacedeskDriver.Server'; name = 'Spacedesk'; cat = 'Gaming'; desc = 'Trasforma tablet o cellulare in un secondo monitor.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Valve.Steam'; name = 'Steam'; cat = 'Gaming'; desc = 'Steam is the ultimate destination for playing, discussing, and creating games.'; pub = 'Valve Corporation'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'ViGEm.ViGEmBus'; name = 'ViGEmBus'; cat = 'Gaming'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'VirtualDesktop.Streamer'; name = 'Virtual Desktop Streamer'; cat = 'Gaming'; desc = 'Virtual Desktop Streamer is a tool that allows you to stream your desktop screen to VR devices.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'NexusMods.Vortex'; name = 'Vortex'; cat = 'Gaming'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'RamenSoftware.Windhawk'; name = 'Windhawk'; cat = 'Gaming'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'HeroicGamesLauncher.HeroicGamesLauncher'; name = 'Heroic Games Launcher'; cat = 'Gaming'; desc = 'Heroic Games Launcher is an open-source alternative game launcher for Epic Games Store.'; pub = ''; src = 'winget'; preset = 'extra'; kind = 'pkg' },
    @{ id = 'Google.ChromeRemoteDesktopHost'; name = 'ChromeRemoteDesktopHost'; cat = 'Cloud e rete'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Google.GoogleDrive'; name = 'Google Drive'; cat = 'Cloud e rete'; desc = 'Safely store your files and access them from any device.'; pub = 'Google LLC'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'LocalSend.LocalSend'; name = 'LocalSend'; cat = 'Cloud e rete'; desc = 'An open-source cross-platform alternative to AirDrop.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Nextcloud.NextcloudDesktop'; name = 'Nextcloud Desktop'; cat = 'Cloud e rete'; desc = 'Nextcloud Desktop is the official desktop client for the Nextcloud file synchronization and sharing platform.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'SSHFS-Win.SSHFS-Win'; name = 'SSHFS-Win'; cat = 'Cloud e rete'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'WinFsp.WinFsp'; name = 'WinFsp'; cat = 'Cloud e rete'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Dropbox.Dropbox'; name = 'Dropbox'; cat = 'Cloud e rete'; desc = 'Organize all your team''s content, tune out distractions, and get everyone coordinated with the world''s first smart workspace.'; pub = 'Dropbox, Inc.'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Apple.iCloud'; name = 'iCloud (Legacy)'; cat = 'Cloud e rete'; desc = 'With iCloud for Windows, you can access your photos, videos, mail, calendar, files, and other important information on your Windows PC.'; pub = 'Apple Inc.'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Microsoft.OneDrive'; name = 'Microsoft OneDrive'; cat = 'Cloud e rete'; desc = 'Keep your files and memories protected, up to date, and easily accessible across all your devices.'; pub = 'Microsoft Corporation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'qBittorrent.qBittorrent'; name = 'qBittorrent'; cat = 'Cloud e rete'; desc = 'Free and reliable P2P Bittorent client.'; pub = 'The qBittorrent project'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'subhra74.XtremeDownloadManager'; name = 'Xtreme Download Manager'; cat = 'Cloud e rete'; desc = 'Xtreme Download Manager (XDM) is a powerful tool to increase download speeds up to 500%, save streaming videos from YouTube, DailyMotion, Facebook, Vimeo, Google Video and 1000+ other websites, resume broken/dead down...'; pub = 'subhra Das Gupta'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'AgileBits.1Password'; name = '1Password'; cat = 'Sicurezza e VPN'; desc = 'Top-Rated Password Manager for Personal & Business Use'; pub = 'AgileBits Inc.'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Bitwarden.Bitwarden'; name = 'Bitwarden'; cat = 'Sicurezza e VPN'; desc = 'A secure and free password manager for all of your devices.'; pub = 'Bitwarden Inc.'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'ESET.Nod32'; name = 'ESET Security'; cat = 'Sicurezza e VPN'; desc = 'Fast and light, vital for gamers and everyday users that dont want any interruptions. Just install and forget. Secures Windows and macOS devices.'; pub = 'ESET, spol. s r.o.'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'KeeperSecurity.KeeperDesktop'; name = 'Keeper(R) Password Manager'; cat = 'Sicurezza e VPN'; desc = 'The top-rated password manager for protecting you, your family and your business from password-related data breaches and cyberthreats.'; pub = 'Keeper Security Inc'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'LastPass.LastPass'; name = 'LastPass'; cat = 'Sicurezza e VPN'; desc = 'An online password manager and form filler that makes web browsing easier and more secure.'; pub = 'LastPass US LP.'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Malwarebytes.Malwarebytes'; name = 'Malwarebytes'; cat = 'Sicurezza e VPN'; desc = 'Cyber Security Software and Anti-Malware'; pub = 'Malwarebytes'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Klocman.BulkCrapUninstaller'; name = 'Bulk Crap Uninstaller'; cat = 'Sistema e tweaks'; desc = 'Bulk Crap Uninstaller is a free and open-source uninstaller utility for Windows. It helps users remove unwanted programs and clean up their system by uninstalling multiple applications at once.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'StartIsBack.StartAllBack'; name = 'StartAllBack'; cat = 'Sistema e tweaks'; desc = 'StartAllBack restores and improves Windows taskbar, Start menu, File Explorer, and shell UI behavior.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'StefanSundin.Superf4'; name = 'SuperF4'; cat = 'Sistema e tweaks'; desc = 'Chiude a forza l app in primo piano con Ctrl+Alt+F4.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'infinitepower18.WSASideloader'; name = 'WSA Sideloader'; cat = 'Sistema e tweaks'; desc = 'Installa APK nel Windows Subsystem for Android.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'rcmaehl.MSEdgeRedirect'; name = 'MSEdgeRedirect'; cat = 'Sistema e tweaks'; desc = 'A Tool to Redirect News, Search, Widgets, Weather, and More to your default browser.'; pub = ''; src = 'winget'; preset = 'extra'; kind = 'pkg' },
    @{ id = 'Nilesoft.Shell'; name = 'Nilesoft Shell'; cat = 'Sistema e tweaks'; desc = 'Shell is an expanded context menu tool that adds extra functionality and customization options to the Windows context menu.'; pub = ''; src = 'winget'; preset = 'extra'; kind = 'pkg' },
    @{ id = 'Devolutions.UniGetUI'; name = 'UniGetUI'; cat = 'Sistema e tweaks'; desc = 'UniGetUI is a GUI for WinGet, Chocolatey, and other Windows CLI package managers.'; pub = ''; src = 'winget'; preset = 'extra'; kind = 'pkg' },
    @{ id = 'Microsoft.PowerToys'; name = 'PowerToys'; cat = 'Sistema e tweaks'; desc = 'Microsoft PowerToys is a set of utilities for power users to tune and streamline their Windows experience for greater productivity.'; pub = 'Microsoft Corporation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = '7zip.7zip'; name = '7-Zip'; cat = 'File e archivi'; desc = 'A file archiver with a high compression ratio.'; pub = 'Igor Pavlov'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'WinDirStat.WinDirStat'; name = 'WinDirStat'; cat = 'File e archivi'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'M2Team.NanaZip'; name = 'NanaZip'; cat = 'File e archivi'; desc = 'NanaZip is a fast and efficient file compression and decompression tool.'; pub = ''; src = 'winget'; preset = 'extra'; kind = 'pkg' },
    @{ id = 'AntibodySoftware.WizTree'; name = 'WizTree'; cat = 'File e archivi'; desc = 'WizTree is a fast disk space analyzer that helps you quickly find the files and folders consuming the most space on your hard drive.'; pub = ''; src = 'winget'; preset = 'extra'; kind = 'pkg' },
    @{ id = 'RARLab.WinRAR'; name = 'WinRAR'; cat = 'File e archivi'; desc = 'Compress, Encrypt, Package and Backup with only one utility.'; pub = 'win.rar GmbH'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Corel.WinZip'; name = 'WinZip'; cat = 'File e archivi'; desc = 'WinZip Compression Utility'; pub = 'Corel Corporation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Bambulab.Bambustudio'; name = 'Bambu Studio'; cat = 'Hardware e monitoraggio'; desc = 'Slicer 3D per stampanti Bambu Lab.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'CrystalDewWorld.CrystalDiskInfo'; name = 'Crystal Disk Info'; cat = 'Hardware e monitoraggio'; desc = 'Crystal Disk Info is a disk health monitoring tool that provides information about the status and performance of hard drives. It helps users anticipate potential issues and monitor drive health.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'CrystalDewWorld.CrystalDiskMark'; name = 'Crystal Disk Mark'; cat = 'Hardware e monitoraggio'; desc = 'Crystal Disk Mark is a disk benchmarking tool that measures the read and write speeds of storage devices. It helps users assess the performance of their hard drives and SSDs.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = '9N1KVPCJP303'; name = 'HP Print Support'; cat = 'Hardware e monitoraggio'; desc = 'Componente di supporto per stampanti HP (Microsoft Store).'; pub = ''; src = 'msstore'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'OpenRGB.OpenRGB'; name = 'OpenRGB'; cat = 'Hardware e monitoraggio'; desc = 'OpenRGB is an open-source RGB lighting control software designed to manage and control RGB lighting for various components and peripherals.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'XP89DCGQ3K6VLD'; name = 'PowerToys (Store)'; cat = 'Hardware e monitoraggio'; desc = 'Utility di produttivita Microsoft (versione Microsoft Store).'; pub = ''; src = 'msstore'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'CPUID.CPU-Z'; name = 'CPU-Z'; cat = 'Hardware e monitoraggio'; desc = 'CPU-Z is a system monitoring and diagnostic tool for Windows. It provides detailed information about the computer''s hardware components, including the CPU, memory, and motherboard.'; pub = ''; src = 'winget'; preset = 'extra'; kind = 'pkg' },
    @{ id = 'TechPowerUp.GPU-Z'; name = 'GPU-Z'; cat = 'Hardware e monitoraggio'; desc = 'GPU-Z provides detailed information about your graphics card and GPU.'; pub = ''; src = 'winget'; preset = 'extra'; kind = 'pkg' },
    @{ id = 'Balena.Etcher'; name = 'Etcher'; cat = 'USB e masterizzazione'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Fedora.FedoraMediaWriter'; name = 'FedoraMediaWriter'; cat = 'USB e masterizzazione'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Rufus.Rufus'; name = 'Rufus Imager'; cat = 'USB e masterizzazione'; desc = 'Rufus is a utility that helps format and create bootable USB drives, such as USB keys or pen drives.'; pub = ''; src = 'winget'; preset = 'extra'; kind = 'pkg' },
    @{ id = 'AnyDesk.AnyDesk'; name = 'AnyDesk'; cat = 'Remoto e supporto'; desc = 'AnyDesk is a remote desktop software that enables users to access and control computers remotely. It is known for its fast connection and low latency.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'TeamViewer.TeamViewer'; name = 'TeamViewer'; cat = 'Remoto e supporto'; desc = 'TeamViewer is a popular remote access and support software that allows you to connect to and control remote devices.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'PuTTY.PuTTY'; name = 'PuTTY'; cat = 'Remoto e supporto'; desc = 'A free implementation of SSH and Telnet for Windows and Unix platforms, along with an xterm terminal emulator.'; pub = 'Simon Tatham'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Splashtop.SplashtopBusiness'; name = 'Splashtop Business'; cat = 'Remoto e supporto'; desc = 'Splashtop Business - Secure Remote Access and Support'; pub = 'Splashtop Inc.'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Termius.Termius'; name = 'Termius'; cat = 'Remoto e supporto'; desc = 'Modern SSH client for Windows'; pub = 'Termius Corporation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Microsoft.DotNet.DesktopRuntime.6'; name = '.NET Desktop Runtime 6'; cat = 'Runtime e librerie'; desc = '.NET Desktop Runtime 6 is a runtime environment required for running applications developed with .NET 6.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.AppInstaller'; name = 'AppInstaller'; cat = 'Runtime e librerie'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.DirectX'; name = 'DirectX'; cat = 'Runtime e librerie'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.DotNet.Native.Runtime'; name = 'DotNet Native Runtime'; cat = 'Runtime e librerie'; desc = 'Runtime .NET Native 2.2.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.GameInput'; name = 'GameInput'; cat = 'Runtime e librerie'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.DotNet.SDK.10'; name = 'Microsoft .NET SDK 10.0'; cat = 'Runtime e librerie'; desc = '.NET is a free, cross-platform, open-source developer platform for building many different types of applications.'; pub = 'Microsoft Corporation'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.DotNet.SDK.9'; name = 'Microsoft .NET SDK 9.0'; cat = 'Runtime e librerie'; desc = '.NET is a free, cross-platform, open-source developer platform for building many different types of applications.'; pub = 'Microsoft Corporation'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.DotNet.DesktopRuntime.8'; name = 'Microsoft .NET Windows Desktop Runtime 8.0'; cat = 'Runtime e librerie'; desc = '.NET is a free, cross-platform, open-source developer platform for building many different types of applications.'; pub = 'Microsoft Corporation'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.DotNet.DesktopRuntime.9'; name = 'Microsoft .NET Windows Desktop Runtime 9.0'; cat = 'Runtime e librerie'; desc = '.NET is a free, cross-platform, open-source developer platform for building many different types of applications.'; pub = 'Microsoft Corporation'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.UI.Xaml.2.8'; name = 'Microsoft UI.Xaml 2.8'; cat = 'Runtime e librerie'; desc = 'Libreria di controlli XAML per app WinUI.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.VCRedist.2008.x64'; name = 'Microsoft Visual C++ 2008 Redistributable - x64'; cat = 'Runtime e librerie'; desc = 'The Microsoft Visual C++ 2008 SP1 Redistributable Package (x64) installs runtime components of Visual C++ Libraries required to run 64-bit applications developed with Visual C++ 2008 SP1 on a computer that does not ha...'; pub = 'Microsoft Corporation'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.VCRedist.2008.x86'; name = 'Microsoft Visual C++ 2008 Redistributable - x86'; cat = 'Runtime e librerie'; desc = 'The Microsoft Visual C++ 2008 SP1 Redistributable Package (x86) installs runtime components of Visual C++ Libraries required to run 32-bit applications developed with Visual C++ 2008 SP1 on a computer that does not ha...'; pub = 'Microsoft Corporation'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.VCRedist.2010.x64'; name = 'Microsoft Visual C++ 2010 x64 Redistributable'; cat = 'Runtime e librerie'; desc = 'The Microsoft Visual C++ 2010 SP1 Redistributable Package (x64) installs runtime components of Visual C++ Libraries required to run 64-bit applications developed with Visual C++ 2010 SP1 on a computer that does not ha...'; pub = 'Microsoft Corporation'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.VCRedist.2010.x86'; name = 'Microsoft Visual C++ 2010 x86 Redistributable'; cat = 'Runtime e librerie'; desc = 'The Microsoft Visual C++ 2010 SP1 Redistributable Package (x86) installs runtime components of Visual C++ Libraries required to run 32-bit applications developed with Visual C++ 2010 SP1 on a computer that does not ha...'; pub = 'Microsoft Corporation'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.VCRedist.2013.x64'; name = 'Microsoft Visual C++ 2013 Redistributable (x64)'; cat = 'Runtime e librerie'; desc = 'The Microsoft Visual C++ 2013 Redistributable Package (x64).'; pub = 'Microsoft Corporation'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.VCRedist.2013.x86'; name = 'Microsoft Visual C++ 2013 Redistributable (x86)'; cat = 'Runtime e librerie'; desc = 'The Microsoft Visual C++ 2013 Redistributable Package (x86)'; pub = 'Microsoft Corporation'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.VCRedist.2015+.x64'; name = 'Microsoft Visual C++ v14 Redistributable (x64)'; cat = 'Runtime e librerie'; desc = 'The Microsoft Visual C++ v14 Redistributable Package (x64).'; pub = 'Microsoft Corporation'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.VCRedist.2015+.x86'; name = 'Microsoft Visual C++ v14 Redistributable (x86)'; cat = 'Runtime e librerie'; desc = 'The Microsoft Visual C++ v14 Redistributable Package (x86)'; pub = 'Microsoft Corporation'; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Nvidia.PhysX'; name = 'PhysX'; cat = 'Runtime e librerie'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.VCLibs.14'; name = 'VCLibs 14'; cat = 'Runtime e librerie'; desc = 'Runtime Visual C++ per app UWP.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.VCLibs.Desktop.14'; name = 'VCLibs Desktop 14'; cat = 'Runtime e librerie'; desc = 'Runtime Visual C++ desktop per app UWP.'; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.WindowsAppRuntime.1.5'; name = 'WindowsAppRuntime 1 5'; cat = 'Runtime e librerie'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.WindowsAppRuntime.1.6'; name = 'WindowsAppRuntime 1 6'; cat = 'Runtime e librerie'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.WindowsAppRuntime.1.7'; name = 'WindowsAppRuntime 1 7'; cat = 'Runtime e librerie'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.WindowsAppRuntime.1.8'; name = 'WindowsAppRuntime 1 8'; cat = 'Runtime e librerie'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.WindowsAppRuntime.2'; name = 'WindowsAppRuntime 2'; cat = 'Runtime e librerie'; desc = ''; pub = ''; src = 'winget'; preset = 'mine'; kind = 'pkg' },
    @{ id = 'Microsoft.DotNet.Framework.Runtime'; name = 'Microsoft .NET Framework Runtime 4.8.1'; cat = 'Runtime e librerie'; desc = 'Do you want to run apps? The runtime includes everything you need to run existing apps/programs built with .NET Framework. Not necessarily to be confused with Microsoft .NET Runtime.'; pub = 'Microsoft Corporation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Microsoft.DotNet.Runtime.10'; name = 'Microsoft .NET Runtime 10.0'; cat = 'Runtime e librerie'; desc = '.NET is a free, cross-platform, open-source developer platform for building many different types of applications.'; pub = 'Microsoft Corporation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Microsoft.DotNet.Runtime.8'; name = 'Microsoft .NET Runtime 8.0'; cat = 'Runtime e librerie'; desc = '.NET is a free, cross-platform, open-source developer platform for building many different types of applications.'; pub = 'Microsoft Corporation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Microsoft.DotNet.Runtime.9'; name = 'Microsoft .NET Runtime 9.0'; cat = 'Runtime e librerie'; desc = '.NET is a free, cross-platform, open-source developer platform for building many different types of applications.'; pub = 'Microsoft Corporation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Microsoft.DotNet.SDK.8'; name = 'Microsoft .NET SDK 8.0'; cat = 'Runtime e librerie'; desc = '.NET is a free, cross-platform, open-source developer platform for building many different types of applications.'; pub = 'Microsoft Corporation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Microsoft.DotNet.DesktopRuntime.10'; name = 'Microsoft .NET Windows Desktop Runtime 10.0'; cat = 'Runtime e librerie'; desc = '.NET is a free, cross-platform, open-source developer platform for building many different types of applications.'; pub = 'Microsoft Corporation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Microsoft.VCRedist.2005.x64'; name = 'Microsoft Visual C++ 2005 Redistributable (x64)'; cat = 'Runtime e librerie'; desc = 'The Microsoft Visual C++ 2005 SP1 Redistributable Package (x64) installs runtime components of Visual C++ Libraries required to run 64-bit applications developed with Visual C++ 2005 SP1 on a computer that does not ha...'; pub = 'Microsoft Corporation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Microsoft.VCRedist.2005.x86'; name = 'Microsoft Visual C++ 2005 Redistributable (x86)'; cat = 'Runtime e librerie'; desc = 'The Microsoft Visual C++ 2005 SP1 Redistributable Package (x86) installs runtime components of Visual C++ Libraries required to run 32-bit applications developed with Visual C++ 2005 SP1 on a computer that does not ha...'; pub = 'Microsoft Corporation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Microsoft.VCRedist.2012.x64'; name = 'Microsoft Visual C++ 2012 Redistributable (x64)'; cat = 'Runtime e librerie'; desc = 'The Microsoft Visual C++ 2012 Redistributable Package (x64) installs runtime components of Visual C++ Libraries required to run 64-bit applications developed with Visual C++ 2012 on a computer that does not have Visua...'; pub = 'Microsoft Corporation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'Microsoft.VCRedist.2012.x86'; name = 'Microsoft Visual C++ 2012 Redistributable (x86)'; cat = 'Runtime e librerie'; desc = 'The Microsoft Visual C++ 2012 Redistributable Package (x86) installs runtime components of Visual C++ Libraries required to run 32-bit applications developed with Visual C++ 2012 on a computer that does not have Visua...'; pub = 'Microsoft Corporation'; src = 'winget'; preset = ''; kind = 'pkg' },
    @{ id = 'mouse-1to1-100'; name = 'Mouse Fix 1:1 @6/11 - ItemsSize 100%'; cat = 'Mouse'; preset = ''; kind = 'mouse'; scale = '100'; sens = '10'; x = '00,00,00,00,00,00,00,00,C0,CC,0C,00,00,00,00,00,80,99,19,00,00,00,00,00,40,66,26,00,00,00,00,00,00,33,33,00,00,00,00,00'; y = '00,00,00,00,00,00,00,00,00,00,38,00,00,00,00,00,00,00,70,00,00,00,00,00,00,00,A8,00,00,00,00,00,00,00,E0,00,00,00,00,00'; speed = '0'; t1 = '0'; t2 = '0'; desc = 'Curva MarkC 1:1, sensibilita 6/11. Vale per ItemsSize 100%. Serve ''Enhance pointer precision'' attiva per i giochi che la forzano.' },
    @{ id = 'mouse-1to1-125'; name = 'Mouse Fix 1:1 @6/11 - ItemsSize 125%'; cat = 'Mouse'; preset = ''; kind = 'mouse'; scale = '125'; sens = '10'; x = '00,00,00,00,00,00,00,00,00,00,10,00,00,00,00,00,00,00,20,00,00,00,00,00,00,00,30,00,00,00,00,00,00,00,40,00,00,00,00,00'; y = '00,00,00,00,00,00,00,00,00,00,38,00,00,00,00,00,00,00,70,00,00,00,00,00,00,00,A8,00,00,00,00,00,00,00,E0,00,00,00,00,00'; speed = '0'; t1 = '0'; t2 = '0'; desc = 'Curva MarkC 1:1, sensibilita 6/11. Vale per ItemsSize 125%. Serve ''Enhance pointer precision'' attiva per i giochi che la forzano.' },
    @{ id = 'mouse-1to1-150'; name = 'Mouse Fix 1:1 @6/11 - ItemsSize 150%'; cat = 'Mouse'; preset = ''; kind = 'mouse'; scale = '150'; sens = '10'; x = '00,00,00,00,00,00,00,00,30,33,13,00,00,00,00,00,60,66,26,00,00,00,00,00,90,99,39,00,00,00,00,00,C0,CC,4C,00,00,00,00,00'; y = '00,00,00,00,00,00,00,00,00,00,38,00,00,00,00,00,00,00,70,00,00,00,00,00,00,00,A8,00,00,00,00,00,00,00,E0,00,00,00,00,00'; speed = '0'; t1 = '0'; t2 = '0'; desc = 'Curva MarkC 1:1, sensibilita 6/11. Vale per ItemsSize 150%. Serve ''Enhance pointer precision'' attiva per i giochi che la forzano.' },
    @{ id = 'mouse-1to1-175'; name = 'Mouse Fix 1:1 @6/11 - ItemsSize 175%'; cat = 'Mouse'; preset = ''; kind = 'mouse'; scale = '175'; sens = '10'; x = '00,00,00,00,00,00,00,00,60,66,16,00,00,00,00,00,C0,CC,2C,00,00,00,00,00,20,33,43,00,00,00,00,00,80,99,59,00,00,00,00,00'; y = '00,00,00,00,00,00,00,00,00,00,38,00,00,00,00,00,00,00,70,00,00,00,00,00,00,00,A8,00,00,00,00,00,00,00,E0,00,00,00,00,00'; speed = '0'; t1 = '0'; t2 = '0'; desc = 'Curva MarkC 1:1, sensibilita 6/11. Vale per ItemsSize 175%. Serve ''Enhance pointer precision'' attiva per i giochi che la forzano.' },
    @{ id = 'mouse-1to1-200'; name = 'Mouse Fix 1:1 @6/11 - ItemsSize 200%'; cat = 'Mouse'; preset = ''; kind = 'mouse'; scale = '200'; sens = '10'; x = '00,00,00,00,00,00,00,00,90,99,19,00,00,00,00,00,20,33,33,00,00,00,00,00,B0,CC,4C,00,00,00,00,00,40,66,66,00,00,00,00,00'; y = '00,00,00,00,00,00,00,00,00,00,38,00,00,00,00,00,00,00,70,00,00,00,00,00,00,00,A8,00,00,00,00,00,00,00,E0,00,00,00,00,00'; speed = '0'; t1 = '0'; t2 = '0'; desc = 'Curva MarkC 1:1, sensibilita 6/11. Vale per ItemsSize 200%. Serve ''Enhance pointer precision'' attiva per i giochi che la forzano.' },
    @{ id = 'mouse-1to1-225'; name = 'Mouse Fix 1:1 @6/11 - ItemsSize 225%'; cat = 'Mouse'; preset = ''; kind = 'mouse'; scale = '225'; sens = '10'; x = '00,00,00,00,00,00,00,00,C0,CC,1C,00,00,00,00,00,80,99,39,00,00,00,00,00,40,66,56,00,00,00,00,00,00,33,73,00,00,00,00,00'; y = '00,00,00,00,00,00,00,00,00,00,38,00,00,00,00,00,00,00,70,00,00,00,00,00,00,00,A8,00,00,00,00,00,00,00,E0,00,00,00,00,00'; speed = '0'; t1 = '0'; t2 = '0'; desc = 'Curva MarkC 1:1, sensibilita 6/11. Vale per ItemsSize 225%. Serve ''Enhance pointer precision'' attiva per i giochi che la forzano.' },
    @{ id = 'mouse-1to1-250'; name = 'Mouse Fix 1:1 @6/11 - ItemsSize 250%'; cat = 'Mouse'; preset = ''; kind = 'mouse'; scale = '250'; sens = '10'; x = '00,00,00,00,00,00,00,00,00,00,20,00,00,00,00,00,00,00,40,00,00,00,00,00,00,00,60,00,00,00,00,00,00,00,80,00,00,00,00,00'; y = '00,00,00,00,00,00,00,00,00,00,38,00,00,00,00,00,00,00,70,00,00,00,00,00,00,00,A8,00,00,00,00,00,00,00,E0,00,00,00,00,00'; speed = '0'; t1 = '0'; t2 = '0'; desc = 'Curva MarkC 1:1, sensibilita 6/11. Vale per ItemsSize 250%. Serve ''Enhance pointer precision'' attiva per i giochi che la forzano.' },
    @{ id = 'mouse-1to1-300'; name = 'Mouse Fix 1:1 @6/11 - ItemsSize 300%'; cat = 'Mouse'; preset = ''; kind = 'mouse'; scale = '300'; sens = '10'; x = '00,00,00,00,00,00,00,00,60,66,26,00,00,00,00,00,C0,CC,4C,00,00,00,00,00,20,33,73,00,00,00,00,00,80,99,99,00,00,00,00,00'; y = '00,00,00,00,00,00,00,00,00,00,38,00,00,00,00,00,00,00,70,00,00,00,00,00,00,00,A8,00,00,00,00,00,00,00,E0,00,00,00,00,00'; speed = '0'; t1 = '0'; t2 = '0'; desc = 'Curva MarkC 1:1, sensibilita 6/11. Vale per ItemsSize 300%. Serve ''Enhance pointer precision'' attiva per i giochi che la forzano.' },
    @{ id = 'mouse-1to1-350'; name = 'Mouse Fix 1:1 @6/11 - ItemsSize 350%'; cat = 'Mouse'; preset = ''; kind = 'mouse'; scale = '350'; sens = '10'; x = '00,00,00,00,00,00,00,00,C0,CC,2C,00,00,00,00,00,80,99,59,00,00,00,00,00,40,66,86,00,00,00,00,00,00,33,B3,00,00,00,00,00'; y = '00,00,00,00,00,00,00,00,00,00,38,00,00,00,00,00,00,00,70,00,00,00,00,00,00,00,A8,00,00,00,00,00,00,00,E0,00,00,00,00,00'; speed = '0'; t1 = '0'; t2 = '0'; desc = 'Curva MarkC 1:1, sensibilita 6/11. Vale per ItemsSize 350%. Serve ''Enhance pointer precision'' attiva per i giochi che la forzano.' },
    @{ id = 'mouse-emul-w9598-2of7'; name = 'Emula W95/98 (2/7 - soglia alta)'; cat = 'Mouse'; preset = ''; kind = 'mouse'; scale = '100'; sens = '10'; x = '00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,20,03,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,28,00,00,00,00,00'; y = '00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,0E,AC,0D,00,00,00,00,00,00,00,00,00,00,00,00,00,5F,01,5E,01,00,00,00,00'; speed = '0'; t1 = '0'; t2 = '0'; desc = 'Emulazione storica dell''accelerazione. Solo ItemsSize 100%. Le varianti a 2 soglie sono ESCLUSE (BSOD su Win10/11 x64).' },
    @{ id = 'mouse-emul-w9598-3of7'; name = 'Emula W95/98 (3/7 - soglia media)'; cat = 'Mouse'; preset = ''; kind = 'mouse'; scale = '100'; sens = '10'; x = '00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,40,02,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,28,00,00,00,00,00'; y = '00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,0A,D8,09,00,00,00,00,00,00,00,00,00,00,00,00,00,5F,01,5E,01,00,00,00,00'; speed = '0'; t1 = '0'; t2 = '0'; desc = 'Emulazione storica dell''accelerazione. Solo ItemsSize 100%. Le varianti a 2 soglie sono ESCLUSE (BSOD su Win10/11 x64).' },
    @{ id = 'mouse-emul-w9598-4of7'; name = 'Emula W95/98 (4/7 - soglia bassa)'; cat = 'Mouse'; preset = ''; kind = 'mouse'; scale = '100'; sens = '10'; x = '00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,60,01,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,28,00,00,00,00,00'; y = '00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,07,04,06,00,00,00,00,00,00,00,00,00,00,00,00,00,5F,01,5E,01,00,00,00,00'; speed = '0'; t1 = '0'; t2 = '0'; desc = 'Emulazione storica dell''accelerazione. Solo ItemsSize 100%. Le varianti a 2 soglie sono ESCLUSE (BSOD su Win10/11 x64).' },
    @{ id = 'mouse-emul-w2k-low'; name = 'Emula Windows 2000 (Low)'; cat = 'Mouse'; preset = ''; kind = 'mouse'; scale = '100'; sens = '10'; x = '00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,40,02,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,28,00,00,00,00,00'; y = '00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,0A,D8,09,00,00,00,00,00,00,00,00,00,00,00,00,00,5F,01,5E,01,00,00,00,00'; speed = '0'; t1 = '0'; t2 = '0'; desc = 'Emulazione storica dell''accelerazione. Solo ItemsSize 100%. Le varianti a 2 soglie sono ESCLUSE (BSOD su Win10/11 x64).' },
    @{ id = 'mouse-welcome'; name = 'Disabilita accelerazione su schermata di benvenuto/login'; cat = 'Mouse'; preset = ''; kind = 'mouse'; scale = ''; sens = ''; x = ''; y = ''; speed = '0'; t1 = '0'; t2 = '0'; desc = 'Zero le soglie nel profilo .DEFAULT: tocca la schermata di login e il primo avvio (dove il pannello utente non vale).' },
    @{ id = 'mouse-default'; name = 'Ripristina curva mouse predefinita di Windows'; cat = 'Mouse'; preset = ''; kind = 'mouse'; scale = ''; sens = ''; x = '00,00,00,00,00,00,00,00,15,6E,00,00,00,00,00,00,00,40,01,00,00,00,00,00,29,DC,03,00,00,00,00,00,00,00,28,00,00,00,00,00'; y = '00,00,00,00,00,00,00,00,FD,11,01,00,00,00,00,00,00,24,04,00,00,00,00,00,00,FC,12,00,00,00,00,00,00,C0,BB,01,00,00,00,00'; speed = ''; t1 = ''; t2 = ''; desc = 'Rimette le curve originali di Windows 10/11 (annulla il mouse fix).' }
)
$Packages = @($Packages | ForEach-Object { [pscustomobject]$_ })
$LogoB64  = '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'

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
