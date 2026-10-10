# Installs tether-agent for the current Windows user and starts it at logon.
# Usage: .\install-agent.ps1 -Binary .\tether-agent.exe -Hub ws://100.64.0.1:7420/ws [-Node laptop]
param(
    [Parameter(Mandatory)] [string] $Binary,
    [Parameter(Mandatory)] [string] $Hub,
    [string] $Node = $env:COMPUTERNAME.ToLower()
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
if (-not (Test-Path $tokenFile)) {
    $token = Read-Host 'Hub token (TETHER_TOKEN from the hub machine)'
    Set-Content -Path $tokenFile -Value $token -NoNewline -Encoding ascii
}

# Run the agent directly, not through a PowerShell wrapper: a wrapper's
# console can close and take the agent down with Ctrl+C (0xC000013A).
# The task runs as the logged-in user so the agent sees your Claude Code
# login and PATH.
$log = Join-Path $dir 'agent.log'
$agentArgs = "-hub `"$Hub`" -node `"$Node`" -token-file `"$tokenFile`" -log `"$log`""
$action = New-ScheduledTaskAction -Execute $exe -Argument $agentArgs -WorkingDirectory $dir
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName 'Tether Agent' -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName 'Tether Agent'
Write-Host "Tether agent installed as '$Node'. Logs: $log"
