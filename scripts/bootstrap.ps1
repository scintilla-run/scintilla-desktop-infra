$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$State = if ($env:SCINTILLA_DESKTOP_STATE) { $env:SCINTILLA_DESKTOP_STATE } else { Join-Path $RepoRoot ".desktop" }
$Src = Join-Path $State "src"
$Bin = Join-Path $State "bin"
$Config = Join-Path $State "config"
$ManifestPath = Join-Path $RepoRoot "appliance.json"
New-Item -ItemType Directory -Force -Path $Src,$Bin,$Config,(Join-Path $State "logs"),(Join-Path $State "runtime") | Out-Null

foreach ($tool in @("git","cargo","zed","python")) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Missing required tool: $tool" }
}
python (Join-Path $RepoRoot "scripts\validate_manifest.py")
if ($LASTEXITCODE -ne 0) { throw "appliance manifest validation failed" }
$Manifest = Get-Content -Raw $ManifestPath | ConvertFrom-Json

function Checkout-Exact([string]$Slug,[string]$Rev,[string]$Dest) {
  if (-not (Test-Path (Join-Path $Dest ".git"))) {
    git clone --filter=blob:none "https://github.com/$Slug.git" $Dest
    if ($LASTEXITCODE -ne 0) { throw "git clone failed for $Slug" }
  }
  git -C $Dest fetch --quiet origin $Rev
  if ($LASTEXITCODE -ne 0) { throw "git fetch failed for $Slug@$Rev" }
  git -C $Dest checkout --quiet --detach $Rev
  if ($LASTEXITCODE -ne 0) { throw "git checkout failed for $Slug@$Rev" }
  $head = (git -C $Dest rev-parse HEAD).Trim()
  if ($head -ne $Rev) { throw "$Slug resolved to $head, expected $Rev" }
}

foreach ($component in $Manifest.components) {
  if ($component.kind -ne "integration-only") {
    Checkout-Exact $component.repo $component.rev (Join-Path $Src $component.name)
  }
}

cargo build --locked --release --manifest-path (Join-Path $Src "desktop-daemon\Cargo.toml")
if ($LASTEXITCODE -ne 0) { throw "desktop daemon build failed" }
Push-Location (Join-Path $Src "cli")
try {
  zed install --frozen
  if ($LASTEXITCODE -ne 0) { throw "zed install failed" }
  cargo build --locked --release
  if ($LASTEXITCODE -ne 0) { throw "CLI build failed" }
} finally { Pop-Location }

Copy-Item (Join-Path $Src "desktop-daemon\target\release\scintilla-desktop-daemon.exe") $Bin -Force
Copy-Item (Join-Path $Src "desktop-daemon\.cli-flags.toml") (Join-Path $Config "scintilla-desktop-daemon.cli-flags.toml") -Force
Copy-Item (Join-Path $Src "cli\target\release\scintilla.exe") $Bin -Force
Copy-Item (Join-Path $Src "cli\.cli-flags.toml") (Join-Path $Bin ".cli-flags.toml") -Force

$EnvFile = Join-Path $State "env.ps1"
@"
$env:SCINTILLA_DAEMON_DATA_DIR = "$(Join-Path $State "runtime")"
$env:SCINTILLA_DAEMON_FLAGS_CONFIG = "$(Join-Path $Config "scintilla-desktop-daemon.cli-flags.toml")"
$env:SCINTILLA_DAEMON_URL = "http://127.0.0.1:8765"
$env:PATH = "$Bin;" + $env:PATH
"@ | Set-Content -Encoding utf8 $EnvFile

Write-Host "Scintilla desktop control plane bootstrapped at $State"
Write-Host "Standalone BEAM shipment remains a promotion gate."
