#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="${SCINTILLA_DESKTOP_STATE:-$ROOT/.desktop}"
python3 "$ROOT/scripts/validate_manifest.py"
failed=0
for tool in git python3 cargo zed cloudflared curl; do
  if command -v "$tool" >/dev/null 2>&1; then printf 'ok   %s\n' "$tool"; else printf 'MISS %s\n' "$tool" >&2; failed=1; fi
done
for binary in scintilla-desktop-daemon scintilla; do
  if [[ -x "$STATE/bin/$binary" ]]; then printf 'ok   %s\n' "$STATE/bin/$binary"; else printf 'MISS %s\n' "$STATE/bin/$binary" >&2; failed=1; fi
done
if [[ -f "$ROOT/runtime.local.json" ]]; then
  python3 -m json.tool "$ROOT/runtime.local.json" >/dev/null
  echo "ok   runtime.local.json"
else
  echo "BLOCK runtime.local.json missing; render it after installing a standalone BEAM shipment" >&2
  failed=1
fi
exit "$failed"
