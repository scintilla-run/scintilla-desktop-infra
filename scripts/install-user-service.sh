#!/usr/bin/env sh
set -eu
root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
os="$(uname -s 2>/dev/null || printf unknown)"
case "$os" in
  Darwin)
    dest="$HOME/Library/LaunchAgents/com.scintilla.desktop-daemon.plist"
    mkdir -p "$(dirname "$dest")"
    sed "s|__SCINTILLA_DESKTOP_INFRA__|$root|g" "$root/service/launchd/com.scintilla.desktop-daemon.plist" > "$dest"
    launchctl bootout "gui/$(id -u)/com.scintilla.desktop-daemon" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/$(id -u)" "$dest"
    ;;
  Linux)
    dest="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/scintilla-desktop-daemon.service"
    mkdir -p "$(dirname "$dest")"
    sed "s|__SCINTILLA_DESKTOP_INFRA__|$root|g" "$root/service/systemd/scintilla-desktop-daemon.service" > "$dest"
    systemctl --user daemon-reload
    systemctl --user enable --now scintilla-desktop-daemon.service
    ;;
  *)
    printf '%s\n' "Use service/windows/README.md on Windows." >&2
    exit 2
    ;;
esac
