#!/usr/bin/env bash
#
# Macflow — desinstalador
# Remove o LaunchAgent e o binário. NÃO apaga sua configuração em ~/.config/macflow.
set -euo pipefail

BIN_PATH="$HOME/.local/bin/macflow"
PLIST_PATH="$HOME/Library/LaunchAgents/com.macflow.agent.plist"
LABEL="com.macflow.agent"
GUI_DOMAIN="gui/$(id -u)"

say() { printf "\033[1;34m▸\033[0m %s\n" "$1"; }

say "Parando e removendo o LaunchAgent…"
launchctl bootout "$GUI_DOMAIN/$LABEL" 2>/dev/null || true
rm -f "$PLIST_PATH"

say "Removendo binário…"
rm -f "$BIN_PATH"

say "Pronto. Sua config em ~/.config/macflow foi preservada."
