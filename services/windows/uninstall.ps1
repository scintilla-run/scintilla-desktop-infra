$ErrorActionPreference = "Stop"
$TaskName = "Scintilla Desktop Daemon"
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($null -ne $task) {
  Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}
Write-Host "Removed Scintilla Desktop Daemon scheduled task; appliance state was preserved."
