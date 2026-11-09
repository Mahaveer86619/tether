# Installs the Tether Windows app for the current user, with Start menu and desktop shortcuts.
# Usage: .\install-app.ps1 [-Build .\app\build\windows\x64\runner\Release] [-NoDesktop]
param(
    [string] $Build = (Join-Path $PSScriptRoot '..\..\app\build\windows\x64\runner\Release'),
    [switch] $NoDesktop
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path (Join-Path $Build 'tether.exe'))) {
    throw "No tether.exe in $Build. Build it first: cd app; flutter build windows --release"
}
$dir = Join-Path $env:LOCALAPPDATA 'Programs\Tether'
$exe = Join-Path $dir 'tether.exe'

Get-Process tether -ErrorAction SilentlyContinue | Where-Object { $_.Path -ieq $exe } |
    Stop-Process -Force -PassThru | Wait-Process -Timeout 10 -ErrorAction SilentlyContinue
# Replace the whole folder so files dropped from a newer build don't linger.
# Windows can hold the old DLLs for a moment after the process exits.
foreach ($try in 1..10) {
    try { if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }; break }
    catch { if ($try -eq 10) { throw }; Start-Sleep -Milliseconds 500 }
}
New-Item -ItemType Directory -Force $dir | Out-Null
Copy-Item (Join-Path $Build '*') $dir -Recurse -Force

$shell = New-Object -ComObject WScript.Shell
$links = @(Join-Path ([Environment]::GetFolderPath('Programs')) 'Tether.lnk')
if (-not $NoDesktop) { $links += Join-Path ([Environment]::GetFolderPath('Desktop')) 'Tether.lnk' }
foreach ($path in $links) {
    $lnk = $shell.CreateShortcut($path)
    $lnk.TargetPath = $exe
    $lnk.WorkingDirectory = $dir
    $lnk.Description = 'Tether: your Claude Code sessions'
    $lnk.Save()
}
Write-Host "Tether app installed to $dir"
