#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="${SCINTILLA_DESKTOP_STATE:-$ROOT/.desktop}"
test -f "$STATE/env" || { echo "not bootstrapped" >&2; exit 1; }
source "$STATE/env"
PID_FILE="$STATE/daemon.pid"
if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "daemon: running pid=$(cat "$PID_FILE")"
else
  echo "daemon: stopped"
fi
TOKEN_FILE="$SCINTILLA_DESKTOP_HOME/token"
if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "daemon token missing: $TOKEN_FILE" >&2
  exit 1
fi
TOKEN="$(cat "$TOKEN_FILE")"
curl --fail --silent -H "Authorization: Bearer $TOKEN" http://127.0.0.1:32123/v1/status
echo
