#!/usr/bin/env bash
#
# Macflow — installer
#
# What it does:
#   1. Builds the binary in release mode.
#   2. Copies the binary to ~/.local/bin/macflow.
#   3. Creates ~/.config/macflow/ and symlinks config.toml (dotfiles style).
#   4. Installs and loads the LaunchAgent (starts at login).
#
# Usage:  ./install.sh
set -euo pipefail

# ── Paths ──────────────────────────────────────────────────────────────────
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
BIN_PATH="$BIN_DIR/macflow"
CONFIG_DIR="$HOME/.config/macflow"
CONFIG_FILE="$CONFIG_DIR/config.toml"
REPO_CONFIG="$REPO_DIR/config.toml"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST_NAME="com.macflow.agent.plist"
PLIST_PATH="$LAUNCH_AGENTS/$PLIST_NAME"
LABEL="com.macflow.agent"

say() { printf "\033[1;34m▸\033[0m %s\n" "$1"; }

# ── 1. Build ───────────────────────────────────────────────────────────────
say "Building Macflow (release)…"
cd "$REPO_DIR"
swift build -c release
BUILT_BIN="$(swift build -c release --show-bin-path)/Macflow"

# ── 2. Install binary ──────────────────────────────────────────────────────
say "Installing binary at $BIN_PATH"
mkdir -p "$BIN_DIR"
install -m 755 "$BUILT_BIN" "$BIN_PATH"

# ── 2b. Code signing ───────────────────────────────────────────────────────
# The Accessibility permission is tied to the signature. With the default
# ad-hoc signature, the cdhash changes on every build and the permission is lost
# (re-prompt). If a self-signed "macflow-codesign" certificate exists in the
# keychain, we sign with it: the permission then applies to any future build.
CODESIGN_CERT="macflow-codesign"
signed_with_cert=false
if security find-certificate -c "$CODESIGN_CERT" >/dev/null 2>&1; then
    say "Signing with the '$CODESIGN_CERT' certificate (persistent permission)"
    if codesign --force --sign "$CODESIGN_CERT" --identifier com.macflow.agent "$BIN_PATH" 2>/dev/null; then
        signed_with_cert=true
    else
        echo "  ⚠ Failed to sign with '$CODESIGN_CERT' — falling back to ad-hoc."
    fi
fi
if [[ "$signed_with_cert" == false ]]; then
    codesign --force --sign - --identifier com.macflow.agent "$BIN_PATH" 2>/dev/null || true
    echo "  ⚠ Ad-hoc signature: the Accessibility permission will need to be"
    echo "    re-granted after every rebuild. To make it permanent,"
    echo "    run once: ./scripts/create-codesign-cert.sh"
fi

# ── 3. Configuration (dotfiles-friendly) ───────────────────────────────────
mkdir -p "$CONFIG_DIR"
# Keep the "source" config inside the repo so it can be versioned in Git.
if [[ ! -e "$REPO_CONFIG" ]]; then
    say "Creating initial config from the template"
    cp "$REPO_DIR/config.toml.example" "$REPO_CONFIG"
fi
# Config symlinking:
#   • If a config already exists (real file OR symlink), leave it untouched —
#     this preserves a custom setup such as a symlink into your dotfiles.
#   • Only create a default symlink (-> repo config) when nothing is there yet.
if [[ -L "$CONFIG_FILE" ]]; then
    say "Config is a symlink -> $(readlink "$CONFIG_FILE") — keeping it."
elif [[ -e "$CONFIG_FILE" ]]; then
    say "A real config.toml already exists — keeping yours."
else
    say "Linking config: $CONFIG_FILE -> $REPO_CONFIG"
    ln -s "$REPO_CONFIG" "$CONFIG_FILE"
fi

# ── 4. LaunchAgent ─────────────────────────────────────────────────────────
say "Installing LaunchAgent"
mkdir -p "$LAUNCH_AGENTS" 2>/dev/null || true

# ~/Library/LaunchAgents must be owned by YOU. If an old installer created it
# as root, writing fails. We detect this and guide you instead of running the
# whole script under sudo (installing the agent as root would run it in the
# wrong session).
if [[ ! -w "$LAUNCH_AGENTS" ]]; then
    echo
    echo "  ✗ No write permission for $LAUNCH_AGENTS"
    echo "    (current owner: $(stat -f '%Su' "$LAUNCH_AGENTS"))."
    echo
    echo "    This folder should be yours. Fix the ownership ONCE with:"
    echo
    echo "        sudo chown -R \"\$(whoami)\":staff \"$LAUNCH_AGENTS\""
    echo
    echo "    Then run ./install.sh again (without sudo)."
    exit 1
fi

sed "s|__BINARY_PATH__|$BIN_PATH|g" "$REPO_DIR/LaunchAgent/$PLIST_NAME" > "$PLIST_PATH"

# Reload the agent (bootout the old one, bootstrap the new one).
GUI_DOMAIN="gui/$(id -u)"
launchctl bootout "$GUI_DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootstrap "$GUI_DOMAIN" "$PLIST_PATH"
launchctl enable "$GUI_DOMAIN/$LABEL" 2>/dev/null || true

say "Done! Macflow is running in the menu bar."
echo
echo "  • Grant the Accessibility permission when prompted"
echo "    (System Settings → Privacy & Security → Accessibility)."
echo "  • Edit your shortcuts in: $REPO_CONFIG"
echo "  • Add ~/.local/bin to your PATH if it isn't already."
