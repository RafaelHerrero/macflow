#!/usr/bin/env bash
#
# Macflow — uninstaller
# Removes the LaunchAgent and the binary. Does NOT delete your config in ~/.config/macflow.
set -euo pipefail

BIN_PATH="$HOME/.local/bin/macflow"
PLIST_PATH="$HOME/Library/LaunchAgents/com.macflow.agent.plist"
LABEL="com.macflow.agent"
GUI_DOMAIN="gui/$(id -u)"

say() { printf "\033[1;34m▸\033[0m %s\n" "$1"; }

say "Stopping and removing the LaunchAgent…"
launchctl bootout "$GUI_DOMAIN/$LABEL" 2>/dev/null || true
rm -f "$PLIST_PATH"

say "Removing binary…"
rm -f "$BIN_PATH"

say "Done. Your config in ~/.config/macflow has been preserved."
