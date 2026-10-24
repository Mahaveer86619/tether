# Builds the Windows app for VERSION and zips it into dist\<version>\tether-windows-<version>.zip.
# Usage: .\tools\release\build-windows.ps1
$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$v = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
$parts = $v.Split('.')
$code = [int]$parts[0] * 10000 + [int]$parts[1] * 100 + [int]$parts[2]
$dist = Join-Path $root "dist\$v"
New-Item -ItemType Directory -Force $dist | Out-Null

Push-Location (Join-Path $root 'app')
try {
    flutter build windows --release --build-name=$v --build-number=$code
    if ($LASTEXITCODE -ne 0) { throw 'flutter build windows failed' }
}
finally { Pop-Location }

$release = Join-Path $root 'app\build\windows\x64\runner\Release'
$zip = Join-Path $dist "tether-windows-$v.zip"
Remove-Item $zip -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $release '*') -DestinationPath $zip
Write-Host "  $zip"
