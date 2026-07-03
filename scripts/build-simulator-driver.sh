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

echo "Patroller resources updated at $ROOT/resources/patrol-simulator-driver"