param(
  [Parameter(Mandatory = $true)][string]$TunnelName,
  [Parameter(Mandatory = $true)][string]$Hostname,
  [string]$ConfigOut = "",
  [string]$Origin = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$State = if ($env:SCINTILLA_DESKTOP_STATE) { $env:SCINTILLA_DESKTOP_STATE } else { Join-Path $Root ".desktop" }
if (-not $ConfigOut) {
  $ConfigOut = Join-Path $State "cloudflare\config.yml"
}
if (-not $Origin) {
  $Origin = if ($env:SCINTILLA_DESKTOP_ORIGIN) { $env:SCINTILLA_DESKTOP_ORIGIN } else { "http://127.0.0.1:8083" }
}

if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) {
  throw "missing required tool: cloudflared"
}

$ConfigDirectory = Split-Path -Parent $ConfigOut
New-Item -ItemType Directory -Force -Path $ConfigDirectory | Out-Null

# Account authentication, tunnel creation, and DNS routing are provisioning
# operations. The desktop daemon should only run the already-provisioned named
# tunnel during normal reconciliation/restart.
& cloudflared tunnel login
if ($LASTEXITCODE -ne 0) {
  throw "cloudflared tunnel login failed"
}

function Get-TunnelId {
  $raw = (& cloudflared tunnel list --output json | Out-String)
  if ($LASTEXITCODE -ne 0) {
    throw "cloudflared tunnel list failed"
  }
  $items = @($raw | ConvertFrom-Json)
  $matches = @($items | Where-Object { $_.name -eq $TunnelName })
  if ($matches.Count -gt 1) {
    throw "multiple Cloudflare tunnels named '$TunnelName'"
  }
  if ($matches.Count -eq 1) {
    return [string]$matches[0].id
  }
  return ""
}

$TunnelId = Get-TunnelId
if (-not $TunnelId) {
  & cloudflared tunnel create $TunnelName
  if ($LASTEXITCODE -ne 0) {
    throw "cloudflared tunnel create failed"
  }
  $TunnelId = Get-TunnelId
}
if (-not $TunnelId) {
  throw "could not resolve UUID for tunnel '$TunnelName' after creation"
}

$CredentialsFile = if ($env:SCINTILLA_CLOUDFLARED_CREDENTIALS_FILE) {
  $env:SCINTILLA_CLOUDFLARED_CREDENTIALS_FILE
} else {
  Join-Path $HOME ".cloudflared\$TunnelId.json"
}
if (-not (Test-Path -LiteralPath $CredentialsFile -PathType Leaf)) {
  throw "Cloudflare tunnel credentials file not found: $CredentialsFile"
}

& cloudflared tunnel route dns $TunnelName $Hostname
if ($LASTEXITCODE -ne 0) {
  throw "cloudflared tunnel route dns failed"
}

function Quote-Yaml([string]$Value) {
  return "'" + ($Value -replace "'", "''") + "'"
}

$yaml = @(
  "tunnel: $TunnelId",
  "credentials-file: $(Quote-Yaml $CredentialsFile)",
  "",
  "ingress:",
  "  - hostname: $Hostname",
  "    service: $Origin",
  "  - service: http_status:404",
  ""
) -join "`n"
Set-Content -LiteralPath $ConfigOut -Value $yaml -Encoding utf8

Write-Host "Provisioned Cloudflare Tunnel '$TunnelName' ($TunnelId)."
Write-Host "DNS hostname: $Hostname"
Write-Host "Origin: $Origin"
Write-Host "Non-secret runtime config: $ConfigOut"
Write-Host "Credentials remain in cloudflared's local credential store: $CredentialsFile"
Write-Host ""
Write-Host "Next: render runtime.local.json with scripts/render_runtime_manifest.py and --cloudflared-config '$ConfigOut'."
