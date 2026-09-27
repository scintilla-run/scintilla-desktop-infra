$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$State = if ($env:SCINTILLA_DESKTOP_STATE) { $env:SCINTILLA_DESKTOP_STATE } else { Join-Path $Root ".desktop" }
$Exe = Join-Path $State "bin\scintilla-desktop-daemon.exe"
if (-not (Test-Path $Exe)) { throw "Run bootstrap first; missing $Exe" }
$Action = New-ScheduledTaskAction -Execute $Exe
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName "Scintilla Desktop Daemon" -Action $Action -Trigger $Trigger -Settings $Settings -Force | Out-Null
Write-Host "Installed Scintilla Desktop Daemon logon task"
