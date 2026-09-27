#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="${SCINTILLA_DESKTOP_STATE:-$ROOT/.desktop}"

if [[ -f "$STATE/env" ]]; then
  source "$STATE/env"
  if [[ -f "$SCINTILLA_DAEMON_DATA_DIR/token" ]]; then
    TOKEN="$(cat "$SCINTILLA_DAEMON_DATA_DIR/token")"
    AUTH="Authorization: Bearer $TOKEN"
    curl --silent -X POST -H "$AUTH" http://127.0.0.1:8765/v1/tunnel/stop >/dev/null || true
    curl --silent -X POST -H "$AUTH" http://127.0.0.1:8765/v1/runtime/stop >/dev/null || true
  fi
fi

if [[ -f "$STATE/daemon.pid" ]]; then
  pid="$(cat "$STATE/daemon.pid")"
  kill "$pid" 2>/dev/null || true
  for _ in {1..30}; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
  done
  kill -9 "$pid" 2>/dev/null || true
  rm -f "$STATE/daemon.pid"
fi
echo "Scintilla desktop appliance stopped"
