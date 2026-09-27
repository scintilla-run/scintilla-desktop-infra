#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="${SCINTILLA_DESKTOP_STATE:-$ROOT/.desktop}"
TUNNEL_NAME="${1:-scintilla-local}"
HOSTNAME="${2:-}"
CONFIG_OUT="${3:-$STATE/cloudflare/config.yml}"
ORIGIN="${SCINTILLA_DESKTOP_ORIGIN:-http://127.0.0.1:8083}"

if [[ -z "$HOSTNAME" ]]; then
  echo "usage: $0 <tunnel-name> <hostname> [config-out]" >&2
  exit 2
fi

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required tool: $1" >&2
    exit 1
  fi
}

need cloudflared
need python3

mkdir -p "$(dirname "$CONFIG_OUT")"

# This is deliberately a bootstrap/provisioning concern. The desktop daemon
# should only run an already-provisioned named tunnel during normal lifecycle
# reconciliation; it must not need account-level DNS mutation on every restart.
cloudflared tunnel login

find_tunnel_id() {
  cloudflared tunnel list --output json | python3 -c '
import json
import sys
name = sys.argv[1]
items = json.load(sys.stdin)
matches = [str(item.get("id", "")) for item in items if item.get("name") == name]
if len(matches) > 1:
    raise SystemExit(f"multiple Cloudflare tunnels named {name!r}")
if matches:
    print(matches[0])
' "$TUNNEL_NAME"
}

TUNNEL_ID="$(find_tunnel_id)"
if [[ -z "$TUNNEL_ID" ]]; then
  cloudflared tunnel create "$TUNNEL_NAME"
  TUNNEL_ID="$(find_tunnel_id)"
fi

if [[ -z "$TUNNEL_ID" ]]; then
  echo "could not resolve UUID for tunnel '$TUNNEL_NAME' after creation" >&2
  exit 1
fi

CREDENTIALS_FILE="${SCINTILLA_CLOUDFLARED_CREDENTIALS_FILE:-$HOME/.cloudflared/$TUNNEL_ID.json}"
if [[ ! -f "$CREDENTIALS_FILE" ]]; then
  echo "Cloudflare tunnel credentials file not found: $CREDENTIALS_FILE" >&2
  echo "Set SCINTILLA_CLOUDFLARED_CREDENTIALS_FILE if cloudflared stored it elsewhere." >&2
  exit 1
fi

cloudflared tunnel route dns "$TUNNEL_NAME" "$HOSTNAME"

cat > "$CONFIG_OUT" <<EOF
tunnel: $TUNNEL_ID
credentials-file: $CREDENTIALS_FILE

ingress:
  - hostname: $HOSTNAME
    service: $ORIGIN
  - service: http_status:404
EOF

chmod 0600 "$CONFIG_OUT"

cat <<EOF
Provisioned Cloudflare Tunnel '$TUNNEL_NAME' ($TUNNEL_ID).
DNS hostname: $HOSTNAME
Origin: $ORIGIN
Non-secret runtime config: $CONFIG_OUT
Credentials remain in cloudflared's local credential store: $CREDENTIALS_FILE

Next:
  python3 "$ROOT/scripts/render_runtime_manifest.py" \
    --ingress-bin /absolute/path/to/scintilla-ingress \
    --ingress-root /absolute/path/to/runtime \
    --cloudflared-config "$CONFIG_OUT" \
    --hostname "$HOSTNAME"
EOF
