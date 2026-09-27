$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$State = if ($env:SCINTILLA_DESKTOP_STATE) { $env:SCINTILLA_DESKTOP_STATE } else { Join-Path $RepoRoot ".desktop" }
$Src = Join-Path $State "src"
$Bin = Join-Path $State "bin"
New-Item -ItemType Directory -Force -Path $Src,$Bin,(Join-Path $State "logs"),(Join-Path $State "runtime") | Out-Null

foreach ($tool in @("git","cargo","zed","python")) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Missing required tool: $tool" }
}
python (Join-Path $RepoRoot "scripts\validate_manifest.py")

function Checkout-Exact([string]$Slug,[string]$Rev,[string]$Dest) {
  if (-not (Test-Path (Join-Path $Dest ".git"))) {
    git clone --filter=blob:none "https://github.com/$Slug.git" $Dest
  }
  git -C $Dest fetch --quiet origin $Rev
  git -C $Dest checkout --quiet --detach $Rev
  $head = (git -C $Dest rev-parse HEAD).Trim()
  if ($head -ne $Rev) { throw "$Slug resolved to $head, expected $Rev" }
}

Checkout-Exact "scintilla-run/scintilla-desktop-daemon" "79d7c65fe3259bca51a37478f2fa304e459c6818" (Join-Path $Src "desktop-daemon")
Checkout-Exact "scintilla-run/gleam-lambda-runner" "8c427f8b77403b1534753639aa06fb6057268c6d" (Join-Path $Src "beam-runner")
Checkout-Exact "scintilla-run/scintilla-cli" "30e589466d264c7349387bde2dc2d31e9501e10c" (Join-Path $Src "cli")

cargo build --locked --release --manifest-path (Join-Path $Src "desktop-daemon\Cargo.toml")
Push-Location (Join-Path $Src "cli")
try {
  zed install --frozen
  cargo build --locked --release
} finally { Pop-Location }

Copy-Item (Join-Path $Src "desktop-daemon\target\release\scintilla-desktop-daemon.exe") $Bin -Force
Copy-Item (Join-Path $Src "cli\target\release\scintilla.exe") $Bin -Force

"Scintilla desktop control plane bootstrapped at $State"
"Standalone BEAM shipment remains a promotion gate."
