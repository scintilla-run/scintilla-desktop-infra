$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$State = if ($env:SCINTILLA_DESKTOP_STATE) { $env:SCINTILLA_DESKTOP_STATE } else { Join-Path $Root ".desktop" }
$Runtime = Join-Path $State "runtime"
$FlagsConfig = Join-Path $State "config\scintilla-desktop-daemon.cli-flags.toml"
$Manifest = if ($env:SCINTILLA_DESKTOP_MANIFEST) { $env:SCINTILLA_DESKTOP_MANIFEST } else { Join-Path $Root "runtime.local.json" }
$Exe = Join-Path $State "bin\scintilla-desktop-daemon.exe"
$TaskName = "Scintilla Desktop Daemon"

if (-not (Test-Path $Exe)) { throw "Run bootstrap first; missing $Exe" }
if (-not (Test-Path $FlagsConfig)) { throw "Missing daemon flags config: $FlagsConfig" }
if (-not (Test-Path $Manifest)) { throw "Missing runtime manifest: $Manifest" }
New-Item -ItemType Directory -Force -Path $Runtime | Out-Null

function Quote-PowerShellLiteral([string]$Value) {
  return "'" + $Value.Replace("'", "''") + "'"
}
$runtimeLiteral = Quote-PowerShellLiteral $Runtime
$flagsLiteral = Quote-PowerShellLiteral $FlagsConfig
$manifestLiteral = Quote-PowerShellLiteral $Manifest
$exeLiteral = Quote-PowerShellLiteral $Exe
$command = @(
  '$ErrorActionPreference = "Stop"',
  ('$env:SCINTILLA_DAEMON_DATA_DIR = ' + $runtimeLiteral),
  ('$env:SCINTILLA_DAEMON_FLAGS_CONFIG = ' + $flagsLiteral),
  ('$env:SCINTILLA_DESKTOP_MANIFEST = ' + $manifestLiteral),
  '$env:SCINTILLA_DAEMON_LISTEN = "127.0.0.1:8765"',
  ('& ' + $exeLiteral)
) -join "; "

$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument ("-NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand " + $encoded)
$Trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$Settings = New-ScheduledTaskSettingsSet -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description "Scintilla desktop daemon for the bootstrapped local appliance" -Force | Out-Null
Start-ScheduledTask -TaskName $TaskName
Write-Host "Installed and started Scintilla Desktop Daemon logon task"
