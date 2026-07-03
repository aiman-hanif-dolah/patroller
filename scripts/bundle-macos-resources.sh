#!/usr/bin/env bash
# Copies native resource bundles into the built macOS app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT/build/macos/Build/Products/Release/patroller.app}"
RESOURCES_DIR="$ROOT/resources"
DEST="$APP_PATH/Contents/Resources"

if [ ! -d "$APP_PATH" ]; then
  echo "error: app bundle not found at $APP_PATH"
  exit 1
fi

mkdir -p "$DEST"

for bundle in patrol-simulator-driver simulator-input-monitor; do
  SRC="$RESOURCES_DIR/$bundle"
  if [ ! -e "$SRC" ]; then
    echo "error: missing resource bundle at $SRC"
    exit 1
  fi
  rm -rf "$DEST/$bundle"
  cp -R "$SRC" "$DEST/$bundle"
  echo "Bundled $bundle -> $DEST/$bundle"
done

if rg -i maestro "$DEST/patrol-simulator-driver" >/dev/null 2>&1; then
  echo "error: Maestro artifacts detected in bundled patrol-simulator-driver"
  exit 1
fi

echo "Resource bundling complete."