#!/usr/bin/env bash
#
# Macflow — one-line remote installer.
#
#   curl -fsSL https://raw.githubusercontent.com/RafaelHerrero/macflow/main/bootstrap.sh | bash
#
# It clones (or updates) the repo into ~/.local/share/macflow and runs install.sh,
# which builds, signs, installs and starts the app. Re-running it updates Macflow.
set -euo pipefail

REPO_URL="${MACFLOW_REPO:-https://github.com/RafaelHerrero/macflow.git}"
SRC_DIR="${MACFLOW_DIR:-$HOME/.local/share/macflow}"

say() { printf "\033[1;34m▸\033[0m %s\n" "$1"; }
die() { printf "\033[1;31m✗\033[0m %s\n" "$1" >&2; exit 1; }

# ── Prerequisites ──────────────────────────────────────────────────────────
[[ "$(uname)" == "Darwin" ]] || die "Macflow only runs on macOS."
command -v git >/dev/null 2>&1 || die "git not found. Install the Xcode Command Line Tools: xcode-select --install"
command -v swift >/dev/null 2>&1 || die "Swift toolchain not found. Run: xcode-select --install   (then re-run this command)"

# ── Clone or update ──────────────────────────────────────────────────────────
if [[ -d "$SRC_DIR/.git" ]]; then
    say "Updating Macflow in $SRC_DIR"
    git -C "$SRC_DIR" pull --ff-only
else
    say "Downloading Macflow into $SRC_DIR"
    mkdir -p "$(dirname "$SRC_DIR")"
    git clone --depth 1 "$REPO_URL" "$SRC_DIR"
fi

# ── Build + install (handles signing, LaunchAgent, config) ───────────────────
cd "$SRC_DIR"
exec ./install.sh
