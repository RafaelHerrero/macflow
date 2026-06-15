#!/usr/bin/env bash
#
# Macflow — installer
#
# What it does:
#   1. Builds the binary in release mode.
#   2. Installs the binary to ~/.local/bin/macflow and signs it with a stable
#      self-signed certificate (created automatically on the first run) so the
#      Accessibility permission survives future rebuilds.
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

# ── 2b. Code signing (stable, self-signed) ─────────────────────────────────
# The Accessibility permission is tied to the binary's signature. An ad-hoc
# signature changes its hash on every build, so macOS treats each rebuild as a
# new app and re-prompts for permission. We sign with a stable self-signed
# certificate instead, so the permission survives all future rebuilds. The
# certificate is created automatically the first time and reused afterwards.
CODESIGN_CERT="macflow-codesign"

# Creates the self-signed code-signing cert if it doesn't exist yet.
# Returns 0 if the cert is available (existing or freshly created), 1 otherwise.
ensure_codesign_cert() {
    security find-certificate -c "$CODESIGN_CERT" >/dev/null 2>&1 && return 0

    say "Creating self-signed signing certificate '$CODESIGN_CERT' (first run only)…"
    local tmp; tmp="$(mktemp -d)" || return 1
    local p12_pw="macflow-import"

    cat > "$tmp/cert.conf" <<EOF
[ req ]
distinguished_name = dn
x509_extensions    = v3
prompt             = no
[ dn ]
CN = $CODESIGN_CERT
[ v3 ]
keyUsage         = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
EOF

    openssl req -x509 -newkey rsa:2048 -nodes \
        -keyout "$tmp/key.pem" -out "$tmp/cert.pem" \
        -days 3650 -config "$tmp/cert.conf" >/dev/null 2>&1 || { rm -rf "$tmp"; return 1; }

    # -legacy + -macalg sha1 + a real password → PKCS12 format Apple's `security` reads.
    openssl pkcs12 -export -legacy -macalg sha1 -out "$tmp/cert.p12" \
        -inkey "$tmp/key.pem" -in "$tmp/cert.pem" \
        -name "$CODESIGN_CERT" -passout pass:"$p12_pw" >/dev/null 2>&1 || { rm -rf "$tmp"; return 1; }

    # -T /usr/bin/codesign pre-authorizes codesign to use the key.
    security import "$tmp/cert.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
        -P "$p12_pw" -T /usr/bin/codesign >/dev/null 2>&1 || { rm -rf "$tmp"; return 1; }

    rm -rf "$tmp"
    echo "  ↳ A keychain dialog may appear when signing — click \"Always Allow\"."
    return 0
}

if ensure_codesign_cert && \
   codesign --force --sign "$CODESIGN_CERT" --identifier com.macflow.agent "$BIN_PATH"; then
    say "Signed with '$CODESIGN_CERT' — Accessibility permission persists across rebuilds."
else
    echo "  ⚠ Could not sign with a stable certificate — using an ad-hoc signature."
    echo "    (The Accessibility permission will need re-granting after each rebuild.)"
    codesign --force --sign - --identifier com.macflow.agent "$BIN_PATH" 2>/dev/null || true
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
