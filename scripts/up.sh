#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="${SCINTILLA_DESKTOP_STATE:-$ROOT/.desktop}"
MANIFEST="${SCINTILLA_DESKTOP_MANIFEST:-$ROOT/runtime.local.json}"
test -f "$STATE/env" || { echo "run scripts/bootstrap.sh first" >&2; exit 1; }
test -f "$MANIFEST" || { echo "missing $MANIFEST; render it with scripts/render_runtime_manifest.py" >&2; exit 1; }
source "$STATE/env"
export SCINTILLA_DESKTOP_MANIFEST="$MANIFEST"
mkdir -p "$SCINTILLA_DESKTOP_HOME" "$STATE/logs"

if [[ ! -f "$STATE/daemon.pid" ]] || ! kill -0 "$(cat "$STATE/daemon.pid")" 2>/dev/null; then
  nohup "$STATE/bin/scintilla-desktop-daemon" >>"$STATE/logs/daemon.log" 2>&1 &
  echo $! > "$STATE/daemon.pid"
fi

for _ in {1..50}; do
  curl --fail --silent http://127.0.0.1:32123/healthz >/dev/null 2>&1 && break
  sleep 0.1
done
curl --fail --silent http://127.0.0.1:32123/healthz >/dev/null

TOKEN="$(cat "$SCINTILLA_DESKTOP_HOME/token")"
AUTH="Authorization: Bearer $TOKEN"
curl --fail --silent -X POST -H "$AUTH" http://127.0.0.1:32123/v1/servers/start >/dev/null

if [[ "${SCINTILLA_START_TUNNEL:-0}" = "1" ]]; then
  curl --fail --silent -X POST -H "$AUTH" -H 'Content-Type: application/json' -d '{}' http://127.0.0.1:32123/v1/tunnel/start >/dev/null
fi

curl --fail --silent -H "$AUTH" http://127.0.0.1:32123/v1/status
echo
