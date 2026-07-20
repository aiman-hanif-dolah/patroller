#!/usr/bin/env bash
# Builds the first-party Patrol simulator driver and stages artifacts under
# patroller/resources/patrol-simulator-driver.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAURI_ROOT="$(cd "$ROOT/../patrol-studio-tauri" && pwd)"

bash "$TAURI_ROOT/scripts/build-simulator-driver.sh"

rm -rf "$ROOT/resources/patrol-simulator-driver"
mkdir -p "$ROOT/resources"
cp -R "$TAURI_ROOT/resources/patrol-simulator-driver" "$ROOT/resources/patrol-simulator-driver"

# Zips are the source of truth; extracted .app bundles are created at install/runtime.
find "$ROOT/resources/patrol-simulator-driver" -depth -type d -name '*.app' -exec rm -rf {} +

echo "Patroller resources updated at $ROOT/resources/patrol-simulator-driver"