#!/usr/bin/env bash
#
# Macflow — build the app icon.
# Runs the Swift generator to produce an .iconset, then packs it into
# Resources/AppIcon.icns with iconutil. Commit the resulting .icns so a normal
# install doesn't need to regenerate it.
#
# Usage:  ./scripts/build-icon.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICONSET="$(mktemp -d)/AppIcon.iconset"
OUT="$REPO_DIR/Resources/AppIcon.icns"

mkdir -p "$REPO_DIR/Resources"
swift "$REPO_DIR/scripts/generate-icon.swift" "$ICONSET"
iconutil -c icns -o "$OUT" "$ICONSET"
rm -rf "$(dirname "$ICONSET")"

echo "▸ Wrote $OUT"
