#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="${SCINTILLA_DESKTOP_STATE:-$ROOT/.desktop}"
BINARY="$STATE/bin/scintilla-desktop-daemon"
RUNTIME="$STATE/runtime"
MANIFEST="${SCINTILLA_DESKTOP_MANIFEST:-$ROOT/runtime.local.json}"
LOGS="$STATE/logs"
test -x "$BINARY" || { echo "run scripts/bootstrap.sh first; missing $BINARY" >&2; exit 1; }
test -f "$MANIFEST" || { echo "missing runtime manifest: $MANIFEST" >&2; exit 1; }
mkdir -p "$RUNTIME" "$LOGS"
escape_sed() { printf '%s' "$1" | sed -e 's/[&|]/\\&/g'; }
case "$(uname -s)" in
  Darwin)
    target="$HOME/Library/LaunchAgents/com.scintilla.desktop-daemon.plist"
    mkdir -p "$(dirname "$target")"
    sed       -e "s|__BINARY__|$(escape_sed "$BINARY")|g"       -e "s|__RUNTIME_DIR__|$(escape_sed "$RUNTIME")|g"       -e "s|__MANIFEST__|$(escape_sed "$MANIFEST")|g"       -e "s|__LOG_DIR__|$(escape_sed "$LOGS")|g"       "$ROOT/services/macos/com.scintilla.desktop-daemon.plist" > "$target"
    chmod 600 "$target"
    launchctl bootout "gui/$(id -u)/com.scintilla.desktop-daemon" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/$(id -u)" "$target"
    launchctl enable "gui/$(id -u)/com.scintilla.desktop-daemon"
    launchctl kickstart -k "gui/$(id -u)/com.scintilla.desktop-daemon"
    ;;
  Linux)
    command -v systemctl >/dev/null 2>&1 || { echo "systemctl is required" >&2; exit 1; }
    unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    target="$unit_dir/scintilla-desktop-daemon.service"
    mkdir -p "$unit_dir"
    sed       -e "s|%h/.local/share/scintilla-desktop/bin/scintilla-desktop-daemon|$(escape_sed "$BINARY")|g"       -e "s|%h/.config/scintilla/runtime.local.json|$(escape_sed "$MANIFEST")|g"       -e "s|%h/.scintilla %h/.local/share/scintilla-desktop %h/.config/scintilla|$(escape_sed "$RUNTIME") $(escape_sed "$STATE") $(escape_sed "$(dirname "$MANIFEST")")|g"       "$ROOT/services/linux/scintilla-desktop-daemon.service" > "$target"
    chmod 600 "$target"
    systemctl --user daemon-reload
    systemctl --user enable --now scintilla-desktop-daemon.service
    ;;
  *)
    echo "unsupported OS; use services/windows/install.ps1 on Windows" >&2
    exit 1
    ;;
esac
echo "Scintilla desktop daemon user service installed"
