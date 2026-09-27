#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
python3 "$root/tests/manifest-contract/check.py"
command -v scintilla-desktop-daemon >/dev/null 2>&1 || printf '%s\n' "warning: scintilla-desktop-daemon is not on PATH" >&2
command -v cloudflared >/dev/null 2>&1 || printf '%s\n' "warning: cloudflared is not on PATH; tunnel features will be unavailable" >&2
manifest="${SCINTILLA_DESKTOP_MANIFEST:-$root/manifests/local-runtime.json}"
if [ ! -f "$manifest" ]; then
  printf '%s\n' "warning: runtime manifest does not exist yet: $manifest" >&2
else
  python3 - "$manifest" <<'PY'
import json, pathlib, sys
p=pathlib.Path(sys.argv[1])
m=json.loads(p.read_text())
if m.get("runtime_kind") != "scintilla-single-beam":
    raise SystemExit("desktop runtime_kind must be scintilla-single-beam")
print(f"manifest: {p}")
print(f"ingress: {m['ingress']['command']['program']}")
print(f"workers: {len(m.get('workers', []))}")
PY
fi
printf '%s\n' "doctor completed"
