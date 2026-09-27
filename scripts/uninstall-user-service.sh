#!/usr/bin/env sh
set -eu
os="$(uname -s 2>/dev/null || printf unknown)"
case "$os" in
  Darwin)
    dest="$HOME/Library/LaunchAgents/com.scintilla.desktop-daemon.plist"
    launchctl bootout "gui/$(id -u)/com.scintilla.desktop-daemon" >/dev/null 2>&1 || true
    rm -f "$dest"
    ;;
  Linux)
    systemctl --user disable --now scintilla-desktop-daemon.service >/dev/null 2>&1 || true
    rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/scintilla-desktop-daemon.service"
    systemctl --user daemon-reload
    ;;
  *)
    printf '%s\n' "Use the Windows Service manager as described in service/windows/README.md." >&2
    exit 2
    ;;
esac
