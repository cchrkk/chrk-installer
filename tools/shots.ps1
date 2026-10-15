<#
.SYNOPSIS
    (dev) Avvia CHRK-Installer, salva uno screenshot della finestra e la chiude.

.DESCRIPTION
    Serve a controllare la resa della GUI (rail, categorie, sezione aggiornamenti) senza
    guardare lo schermo: lancia lo script, aspetta che la scansione finisca, cattura la
    finestra in un PNG e termina il processo.

.EXAMPLE
    .\tools\shots.ps1
    .\tools\shots.ps1 -Script dist\CHRK-Installer.ps1 -Wait 25 -Out $env:TEMP\gui.png
#>
[CmdletBinding()]
param(
    [string]$Script = 'dist\CHRK-Installer.ps1',
    [int]$Wait = 22,
    [string]$Out = (Join-Path $env:TEMP 'chrk-installer.png')
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32Shot {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
"@

$proc = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Script -PassThru
Write-Host "avviato (pid $($proc.Id)), attendo $Wait s..."
Start-Sleep -Seconds $Wait
$proc.Refresh()

$h = $proc.MainWindowHandle
if ($h -eq [IntPtr]::Zero) {
    $win = Get-Process powershell -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like 'CHRK Installer*' } | Select-Object -First 1
    if ($win) { $h = $win.MainWindowHandle; $proc = $win }
}
if ($h -eq [IntPtr]::Zero) {
    Write-Error 'Finestra non trovata: lo script si e aperto?'
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    exit 1
}

[void][Win32Shot]::ShowWindow($h, 5)
[void][Win32Shot]::SetForegroundWindow($h)
Start-Sleep -Milliseconds 900
$r = New-Object Win32Shot+RECT
[void][Win32Shot]::GetWindowRect($h, [ref]$r)
$w = $r.R - $r.L; $ht = $r.B - $r.T

$bmp = New-Object System.Drawing.Bitmap $w, $ht
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.L, $r.T, 0, 0, (New-Object System.Drawing.Size $w, $ht))
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host "screenshot: $Out"

Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
Write-Host 'finestra chiusa'
