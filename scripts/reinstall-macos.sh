#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE_DIR="$ROOT/build/macos/Build/Products/Release"
INSTALL_NAME="Patroller.app"
INSTALL_PATH="/Applications/$INSTALL_NAME"

resolve_build_app() {
  local candidate
  for candidate in Patroller.app patroller.app; do
    if [ -d "$RELEASE_DIR/$candidate/Contents" ]; then
      printf '%s' "$RELEASE_DIR/$candidate"
      return 0
    fi
  done
  return 1
}

verify_app_bundle() {
  local app_path="$1"
  if [ ! -f "$app_path/Contents/Info.plist" ]; then
    echo "error: $app_path is not a valid macOS app bundle (missing Contents/Info.plist)"
    return 1
  fi
  if [ -d "$app_path/patroller.app" ] || [ -d "$app_path/Patroller.app" ]; then
    echo "error: $app_path contains a nested .app bundle — refusing to install"
    return 1
  fi
  return 0
}

cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter not found on PATH"
  exit 1
fi

echo "→ flutter pub get"
flutter pub get

echo "→ flutter build macos --release"
flutter build macos --release

BUILD_APP="$(resolve_build_app || true)"
if [ -z "${BUILD_APP:-}" ]; then
  echo "error: no app bundle found in $RELEASE_DIR"
  echo "expected Patroller.app or patroller.app"
  ls -la "$RELEASE_DIR" 2>/dev/null || true
  exit 1
fi

verify_app_bundle "$BUILD_APP"

echo "→ bundle macOS resources into $(basename "$BUILD_APP")"
bash "$ROOT/scripts/bundle-macos-resources.sh" "$BUILD_APP"
verify_app_bundle "$BUILD_APP"

echo "→ remove old installs"
rm -rf "/Applications/patroller.app" "$INSTALL_PATH"

echo "→ install $INSTALL_PATH"
ditto "$BUILD_APP" "$INSTALL_PATH"

DISPLAY_NAME="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' \
    "$INSTALL_PATH/Contents/Info.plist" 2>/dev/null || echo unknown
)"
BUNDLE_NAME="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleName' \
    "$INSTALL_PATH/Contents/Info.plist" 2>/dev/null || echo unknown
)"

echo "✓ Installed $INSTALL_PATH"
echo "  CFBundleDisplayName: $DISPLAY_NAME"
echo "  CFBundleName: $BUNDLE_NAME"
echo "  Built from: $BUILD_APP"