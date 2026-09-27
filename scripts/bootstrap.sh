#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="${SCINTILLA_DESKTOP_STATE:-$ROOT/.desktop}"
SRC="$STATE/src"
BIN="$STATE/bin"
mkdir -p "$SRC" "$BIN" "$STATE/logs"
python3 "$ROOT/scripts/validate_manifest.py"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing required tool: $1" >&2; exit 1; }; }
for tool in git python3 cargo zed; do need "$tool"; done

checkout() {
  local slug="$1" rev="$2" dest="$3"
  if [[ ! -d "$dest/.git" ]]; then
    git clone --filter=blob:none "https://github.com/$slug.git" "$dest"
  fi
  git -C "$dest" fetch --quiet origin "$rev"
  git -C "$dest" checkout --quiet --detach "$rev"
  test "$(git -C "$dest" rev-parse HEAD)" = "$rev"
}

checkout scintilla-run/scintilla-desktop-daemon 79d7c65fe3259bca51a37478f2fa304e459c6818 "$SRC/desktop-daemon"
checkout scintilla-run/gleam-lambda-runner 8c427f8b77403b1534753639aa06fb6057268c6d "$SRC/beam-runner"
checkout scintilla-run/scintilla-cli 30e589466d264c7349387bde2dc2d31e9501e10c "$SRC/cli"

cargo build --locked --release --manifest-path "$SRC/desktop-daemon/Cargo.toml"
( cd "$SRC/cli" && zed install --frozen && cargo build --locked --release )

cp "$SRC/desktop-daemon/target/release/scintilla-desktop-daemon" "$BIN/"
cp "$SRC/cli/target/release/scintilla" "$BIN/"
chmod 0755 "$BIN/"*

mkdir -p "$STATE/runtime"
cat > "$STATE/env" <<EOF
export SCINTILLA_DESKTOP_HOME="$STATE/runtime"
export SCINTILLA_DAEMON_URL="http://127.0.0.1:32123"
export PATH="$BIN:\$PATH"
EOF

echo "Scintilla desktop control plane bootstrapped at $STATE"
echo "BEAM runner source is pinned at $SRC/beam-runner."
echo "Promotion remains blocked until a standalone BEAM shipment is available."
