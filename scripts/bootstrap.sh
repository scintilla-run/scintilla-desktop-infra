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

python3 - "$ROOT/appliance.json" "$SRC" <<'PY'
import json, pathlib, subprocess, sys
manifest=json.loads(pathlib.Path(sys.argv[1]).read_text())
root=pathlib.Path(sys.argv[2])
for component in manifest["components"]:
    if component.get("kind") == "integration-only":
        continue
    dest=root/component["name"]
    repo="https://github.com/"+component["repo"]+".git"
    rev=component["rev"]
    if not (dest/".git").exists():
        subprocess.run(["git","clone","--filter=blob:none",repo,str(dest)],check=True)
    subprocess.run(["git","-C",str(dest),"fetch","--quiet","origin",rev],check=True)
    subprocess.run(["git","-C",str(dest),"checkout","--quiet","--detach",rev],check=True)
    actual=subprocess.check_output(["git","-C",str(dest),"rev-parse","HEAD"],text=True).strip()
    if actual != rev:
        raise SystemExit(f"{component['name']}: expected {rev}, got {actual}")
PY

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
echo "BEAM runner source is pinned from appliance.json at $SRC/beam-runner."
echo "Promotion remains blocked until a supported standalone BEAM shipment is available."
