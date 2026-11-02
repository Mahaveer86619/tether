# Installs tether-agent for the current Windows user as an on-demand task; the Tether app starts it.
# Usage: .\install-agent.ps1 -Binary .\tether-agent.exe -Hub ws://100.64.0.1:7420/ws [-Node laptop] [-PairCode ABCDE-FGHJK] [-Fingerprint <sha256>]
# -PairCode (from the app's "Add a device" or `tetherctl pair`) gives the node its own token;
# without it the hub's admin token is asked for once. -Fingerprint pins a self-signed hub certificate.
param(
    [Parameter(Mandatory)] [string] $Binary,
    [Parameter(Mandatory)] [string] $Hub,
    [string] $Node = $env:COMPUTERNAME.ToLower(),
    [string] $PairCode = '',
    [string] $Fingerprint = ''
)
$ErrorActionPreference = 'Stop'

$dir = Join-Path $env:USERPROFILE '.tether'
$exe = Join-Path $dir 'bin\tether-agent.exe'
New-Item -ItemType Directory -Force (Join-Path $dir 'bin') | Out-Null
Stop-ScheduledTask -TaskName 'Tether Agent' -ErrorAction SilentlyContinue
Get-Process tether-agent -ErrorAction SilentlyContinue | Stop-Process -Force -PassThru | Wait-Process -Timeout 10 -ErrorAction SilentlyContinue
# Windows can hold the old binary open for a moment after the process exits.
foreach ($try in 1..10) {
    try { Copy-Item $Binary $exe -Force; break }
    catch { if ($try -eq 10) { throw }; Start-Sleep -Milliseconds 500 }
}
Remove-Item (Join-Path $dir 'run-agent.ps1') -ErrorAction SilentlyContinue

$tokenFile = Join-Path $dir 'token'
if ($PairCode) {
    & $exe pair -hub $Hub -node $Node -token-file $tokenFile -fingerprint $Fingerprint $PairCode
    if ($LASTEXITCODE -ne 0) { throw 'Pairing failed' }
}
elseif (-not (Test-Path $tokenFile)) {
    $token = Read-Host 'Hub token (TETHER_TOKEN from the hub machine)'
    Set-Content -Path $tokenFile -Value $token -NoNewline -Encoding ascii
}

# Run the agent directly, not through a PowerShell wrapper: a wrapper's
# console can close and take the agent down with Ctrl+C (0xC000013A).
# The task runs as the logged-in user so the agent sees your Claude Code
# login and PATH.
$log = Join-Path $dir 'agent.log'
$agentArgs = "-hub `"$Hub`" -node `"$Node`" -token-file `"$tokenFile`" -log `"$log`""
if ($Fingerprint) { $agentArgs += " -fingerprint $Fingerprint" }
$action = New-ScheduledTaskAction -Execute $exe -Argument $agentArgs -WorkingDirectory $dir
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName 'Tether Agent' -Action $action -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName 'Tether Agent'
Write-Host "Tether agent installed as '$Node'. Logs: $log"
