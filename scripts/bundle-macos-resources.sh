#!/usr/bin/env bash
# Copies native resource bundles into the built macOS app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_DIR="$ROOT/build/macos/Build/Products/Release"

resolve_build_app() {
  if [ -n "${1:-}" ]; then
    printf '%s' "$1"
    return 0
  fi
  local candidate
  for candidate in "$RELEASE_DIR/Patroller.app" "$RELEASE_DIR/patroller.app"; do
    if [ -d "$candidate" ]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

APP_PATH="$(resolve_build_app "${1:-}" || true)"
if [ -z "${APP_PATH:-}" ]; then
  echo "error: app bundle not found in $RELEASE_DIR (expected Patroller.app or patroller.app)"
  exit 1
fi
RESOURCES_DIR="$ROOT/resources"
DEST="$APP_PATH/Contents/Resources"

if [ ! -d "$APP_PATH" ]; then
  echo "error: app bundle not found at $APP_PATH"
  exit 1
fi

mkdir -p "$DEST"

extract_simulator_driver_zips() {
  local root="$1"
  local build_dir="$root/simulator/Debug-iphonesimulator"
  if [ ! -d "$build_dir" ]; then
    return 0
  fi
  for zip in "$build_dir"/*.zip; do
    [ -f "$zip" ] || continue
    /usr/bin/ditto -x -k "$zip" "$build_dir"
  done
}

for bundle in patrol-simulator-driver simulator-input-monitor; do
  SRC="$RESOURCES_DIR/$bundle"
  if [ ! -e "$SRC" ]; then
    echo "error: missing resource bundle at $SRC"
    exit 1
  fi
  rm -rf "$DEST/$bundle"
  cp -R "$SRC" "$DEST/$bundle"
  if [ "$bundle" = "patrol-simulator-driver" ]; then
    extract_simulator_driver_zips "$DEST/$bundle"
  fi
  echo "Bundled $bundle -> $DEST/$bundle"
done

# Keep dev resources in sync so flutter run finds extracted runner apps too.
extract_simulator_driver_zips "$RESOURCES_DIR/patrol-simulator-driver"

echo "Resource bundling complete."