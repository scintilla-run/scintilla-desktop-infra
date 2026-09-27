$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$State = if ($env:SCINTILLA_DESKTOP_STATE) { $env:SCINTILLA_DESKTOP_STATE } else { Join-Path $RepoRoot ".desktop" }
$EnvFile = Join-Path $State "env.ps1"
if (-not (Test-Path $EnvFile)) { throw "not bootstrapped" }
. $EnvFile
$PidFile = Join-Path $State "daemon.pid"
$Running = $false
$pidValue = $null
if (Test-Path $PidFile) {
  $pidValue = (Get-Content -Raw $PidFile).Trim()
  if ($pidValue) { $Running = $null -ne (Get-Process -Id ([int]$pidValue) -ErrorAction SilentlyContinue) }
}
if ($Running) { Write-Host ("daemon: running pid=" + $pidValue) } else { Write-Host "daemon: stopped" }
$TokenFile = Join-Path $env:SCINTILLA_DAEMON_DATA_DIR "token"
if (-not (Test-Path $TokenFile)) { throw "daemon token missing: $TokenFile" }
$Token = (Get-Content -Raw $TokenFile).Trim()
$Headers = @{ Authorization = "Bearer $Token" }
Invoke-RestMethod -Headers $Headers -Uri "http://127.0.0.1:8765/v1/status" | ConvertTo-Json -Depth 8
