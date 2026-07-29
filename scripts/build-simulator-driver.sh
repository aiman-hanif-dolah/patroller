#!/usr/bin/env bash
# Builds the first-party Patrol simulator driver and stages artifacts under
# patroller/resources/patrol-simulator-driver.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAURI_ROOT="${PATROL_STUDIO_TAURI_ROOT:-$ROOT/../patrol-studio-tauri}"
if [ ! -f "$TAURI_ROOT/scripts/build-simulator-driver.sh" ]; then
  echo "error: simulator driver source not found at $TAURI_ROOT" >&2
  echo "set PATROL_STUDIO_TAURI_ROOT to the patrol-studio-tauri checkout" >&2
  exit 1
fi
TAURI_ROOT="$(cd "$TAURI_ROOT" && pwd)"

bash "$TAURI_ROOT/scripts/build-simulator-driver.sh"

rm -rf "$ROOT/resources/patrol-simulator-driver"
mkdir -p "$ROOT/resources"
cp -R "$TAURI_ROOT/resources/patrol-simulator-driver" "$ROOT/resources/patrol-simulator-driver"

# Zips are the source of truth; extracted .app bundles are created at install/runtime.
find "$ROOT/resources/patrol-simulator-driver" -depth -type d -name '*.app' -exec rm -rf {} +

echo "Patroller resources updated at $ROOT/resources/patrol-simulator-driver"
