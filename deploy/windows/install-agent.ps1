# Installs tether-agent for the current Windows user and starts it at logon.
# Usage: .\install-agent.ps1 -Binary .\tether-agent.exe -Hub ws://100.64.0.1:7420/ws [-Node laptop]
param(
    [Parameter(Mandatory)] [string] $Binary,
    [Parameter(Mandatory)] [string] $Hub,
    [string] $Node = $env:COMPUTERNAME.ToLower()
)
$ErrorActionPreference = 'Stop'

$dir = Join-Path $env:USERPROFILE '.tether'
New-Item -ItemType Directory -Force (Join-Path $dir 'bin') | Out-Null
Copy-Item $Binary (Join-Path $dir 'bin\tether-agent.exe') -Force

$tokenFile = Join-Path $dir 'token'
if (-not (Test-Path $tokenFile)) {
    $token = Read-Host 'Hub token (TETHER_TOKEN from the hub machine)'
    Set-Content -Path $tokenFile -Value $token -NoNewline -Encoding ascii
}

# The task runs as the logged-in user so the agent sees your Claude Code login and PATH.
$launcher = Join-Path $dir 'run-agent.ps1'
@"
`$env:TETHER_TOKEN = (Get-Content -Raw '$tokenFile').Trim()
& '$dir\bin\tether-agent.exe' -hub '$Hub' -node '$Node' *>> '$dir\agent.log'
"@ | Set-Content -Path $launcher -Encoding utf8

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$launcher`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero)
Register-ScheduledTask -TaskName 'Tether Agent' -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName 'Tether Agent'
Write-Host "Tether agent installed as '$Node'. Logs: $dir\agent.log"
