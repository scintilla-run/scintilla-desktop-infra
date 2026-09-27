#!/usr/bin/env bash
set -euo pipefail
case "$(uname -s)" in
  Darwin)
    target="$HOME/Library/LaunchAgents/run.scintilla.desktop-daemon.plist"
    launchctl bootout "gui/$(id -u)/run.scintilla.desktop-daemon" >/dev/null 2>&1 || true
    rm -f "$target"
    ;;
  Linux)
    systemctl --user disable --now scintilla-desktop-daemon.service >/dev/null 2>&1 || true
    rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/scintilla-desktop-daemon.service"
    systemctl --user daemon-reload
    ;;
  *)
    echo "unsupported OS; use services/windows/uninstall.ps1 on Windows" >&2
    exit 1
    ;;
esac
echo "Scintilla desktop daemon user service removed; appliance state preserved"
