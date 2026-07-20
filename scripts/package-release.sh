#!/usr/bin/env bash
# Build downloadable Patroller release artifacts for the current host OS.
#
# macOS  -> dist/Patroller-<version>-macos-arm64.zip
#          dist/Patroller-<version>-macos-arm64.dmg
# Windows-> dist/Patroller-<version>-windows-x64.zip  (run on Windows)
#
# Usage:
#   ./scripts/package-release.sh
#   ./scripts/package-release.sh --skip-devtools   # faster local iteration
#   ./scripts/package-release.sh --macos-only
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SKIP_DEVTOOLS=0
MACOS_ONLY=0
WINDOWS_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --skip-devtools) SKIP_DEVTOOLS=1 ;;
    --macos-only) MACOS_ONLY=1 ;;
    --windows-only) WINDOWS_ONLY=1 ;;
    -h|--help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
  esac
done

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter not found on PATH"
  exit 1
fi

VERSION="$(
  python3 - <<'PY'
import re
from pathlib import Path
text = Path("pubspec.yaml").read_text()
m = re.search(r"^version:\s*([^\s#+]+)", text, re.M)
print(m.group(1) if m else "0.0.0")
PY
)"
BUILD_NUMBER="$(
  python3 - <<'PY'
import re
from pathlib import Path
text = Path("pubspec.yaml").read_text()
m = re.search(r"^version:\s*[^\s#]+(?:\+(\d+))?", text, re.M)
print(m.group(1) if m and m.group(1) else "0")
PY
)"

DIST="$ROOT/dist"
mkdir -p "$DIST"

HOST_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "$ARCH" in
  arm64|aarch64) ARCH_LABEL="arm64" ;;
  x86_64|amd64) ARCH_LABEL="x64" ;;
  *) ARCH_LABEL="$ARCH" ;;
esac

echo "→ Patroller release packaging"
echo "  version: $VERSION+$BUILD_NUMBER"
echo "  host:    $HOST_OS ($ARCH_LABEL)"
echo "  out:     $DIST"
echo

echo "→ flutter pub get"
flutter pub get

build_devtools_panel() {
  if [ "$SKIP_DEVTOOLS" -eq 1 ]; then
    echo "→ skip DevTools panel rebuild (--skip-devtools)"
    return 0
  fi
  if [ ! -d "$ROOT/devtools_extension" ]; then
    echo "→ warn: devtools_extension/ missing - skipping panel build"
    return 0
  fi
  echo "→ build DevTools panel (web)"
  (
    cd "$ROOT/devtools_extension"
    flutter pub get
    flutter build web --release \
      --base-href=/panel/ \
      --no-tree-shake-icons
    perl -i -pe 's|<base href="/panel/"\s*/?>|<base href="/">|' build/web/index.html
    rm -rf "$ROOT/extension/devtools/build"
    mkdir -p "$ROOT/extension/devtools"
    cp -R build/web "$ROOT/extension/devtools/build"
  )
  echo "  DevTools panel → extension/devtools/build"
}

package_macos() {
  local release_dir="$ROOT/build/macos/Build/Products/Release"
  local app_path=""
  local candidate
  for candidate in Patroller.app patroller.app; do
    if [ -d "$release_dir/$candidate/Contents" ]; then
      app_path="$release_dir/$candidate"
      break
    fi
  done
  if [ -z "$app_path" ]; then
    echo "error: Patroller.app not found under $release_dir"
    ls -la "$release_dir" 2>/dev/null || true
    exit 1
  fi
  if [ ! -f "$app_path/Contents/Info.plist" ]; then
    echo "error: invalid app bundle at $app_path"
    exit 1
  fi

  echo "→ bundle macOS resources"
  bash "$ROOT/scripts/bundle-macos-resources.sh" "$app_path"

  # Stage a clean copy so zip/dmg roots are exactly Patroller.app
  local stage="$DIST/stage-macos"
  rm -rf "$stage"
  mkdir -p "$stage"
  /usr/bin/ditto "$app_path" "$stage/Patroller.app"

  local zip_name="Patroller-${VERSION}-macos-${ARCH_LABEL}.zip"
  local dmg_name="Patroller-${VERSION}-macos-${ARCH_LABEL}.dmg"
  local zip_path="$DIST/$zip_name"
  local dmg_path="$DIST/$dmg_name"

  echo "→ create $zip_name"
  rm -f "$zip_path"
  (
    cd "$stage"
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent Patroller.app "$zip_path"
  )

  echo "→ create $dmg_name"
  rm -f "$dmg_path"
  hdiutil create \
    -volname "Patroller $VERSION" \
    -srcfolder "$stage/Patroller.app" \
    -ov \
    -format UDZO \
    "$dmg_path" >/dev/null

  # Lightweight install helper next to the archives
  cat > "$DIST/install-macos.sh" <<'EOS'
#!/usr/bin/env bash
# Install Patroller.app into /Applications from a downloaded zip or dmg sibling.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SRC=""
if [ -d "$DIR/Patroller.app" ]; then
  APP_SRC="$DIR/Patroller.app"
elif ls "$DIR"/Patroller-*-macos-*.zip >/dev/null 2>&1; then
  ZIP="$(ls -1 "$DIR"/Patroller-*-macos-*.zip | head -1)"
  TMP="$(mktemp -d)"
  unzip -q "$ZIP" -d "$TMP"
  APP_SRC="$(find "$TMP" -maxdepth 2 -name 'Patroller.app' -type d | head -1)"
elif ls "$DIR"/Patroller-*-macos-*.dmg >/dev/null 2>&1; then
  DMG="$(ls -1 "$DIR"/Patroller-*-macos-*.dmg | head -1)"
  MNT="$(mktemp -d)"
  hdiutil attach "$DMG" -mountpoint "$MNT" -nobrowse -quiet
  APP_SRC="$MNT/Patroller.app"
  trap 'hdiutil detach "$MNT" -quiet || true' EXIT
fi
if [ -z "${APP_SRC:-}" ] || [ ! -d "$APP_SRC" ]; then
  echo "error: could not find Patroller.app next to this script"
  exit 1
fi
DEST="/Applications/Patroller.app"
echo "Installing to $DEST ..."
rm -rf "$DEST"
/usr/bin/ditto "$APP_SRC" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
echo "Done. Open with: open -a Patroller"
EOS
  chmod +x "$DIST/install-macos.sh"

  rm -rf "$stage"

  echo
  echo "macOS artifacts:"
  ls -lh "$zip_path" "$dmg_path" "$DIST/install-macos.sh"
  echo
  echo "Install options:"
  echo "  1) Open the .dmg and drag Patroller to Applications"
  echo "  2) Unzip the .zip and drag Patroller.app to Applications"
  echo "  3) Run: ./dist/install-macos.sh  (after placing zip/dmg in dist/)"
}

package_windows() {
  local release_dir="$ROOT/build/windows/x64/runner/Release"
  if [ ! -d "$release_dir" ]; then
    echo "error: Windows release folder not found at $release_dir"
    echo "run this script on Windows after: flutter build windows --release"
    exit 1
  fi
  if [ ! -f "$release_dir/patroller.exe" ] && [ ! -f "$release_dir/Patroller.exe" ]; then
    echo "error: patroller.exe not found in $release_dir"
    ls -la "$release_dir" || true
    exit 1
  fi

  local zip_name="Patroller-${VERSION}-windows-x64.zip"
  local zip_path="$DIST/$zip_name"
  rm -f "$zip_path"

  echo "→ create $zip_name"
  if command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command \
      "Compress-Archive -Path '$(cygpath -w "$release_dir" 2>/dev/null || echo "$release_dir")\\*' -DestinationPath '$(cygpath -w "$zip_path" 2>/dev/null || echo "$zip_path")' -Force"
  elif command -v zip >/dev/null 2>&1; then
    (
      cd "$release_dir"
      zip -r "$zip_path" .
    )
  else
    echo "error: need zip or powershell to package Windows build"
    exit 1
  fi

  cat > "$DIST/install-windows.txt" <<EOF
Patroller $VERSION for Windows
==============================

1. Unzip $zip_name to a folder (e.g. %LOCALAPPDATA%\\Patroller).
2. Run patroller.exe (or Patroller.exe).
3. Optional: pin the exe to the taskbar / Start menu.

No admin install is required for the portable zip.
EOF

  echo
  echo "Windows artifacts:"
  ls -lh "$zip_path" "$DIST/install-windows.txt"
}

build_devtools_panel

if [ "$WINDOWS_ONLY" -eq 1 ]; then
  echo "→ flutter build windows --release"
  flutter build windows --release
  package_windows
elif [ "$MACOS_ONLY" -eq 1 ] || [ "$HOST_OS" = "darwin" ]; then
  if [ "$HOST_OS" != "darwin" ]; then
    echo "error: macOS packaging requires Darwin"
    exit 1
  fi
  echo "→ flutter build macos --release"
  flutter build macos --release
  package_macos
elif [[ "$HOST_OS" == mingw* || "$HOST_OS" == msys* || "$HOST_OS" == cygwin* || "$HOST_OS" == windows* ]]; then
  echo "→ flutter build windows --release"
  flutter build windows --release
  package_windows
else
  echo "error: unsupported host OS: $HOST_OS"
  echo "Build macOS on a Mac, Windows on a Windows machine, or use GitHub Actions."
  exit 1
fi

# Checksums for release notes / verification
echo "→ checksums"
(
  cd "$DIST"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 Patroller-"$VERSION"-* 2>/dev/null | tee "SHA256SUMS-${VERSION}.txt" || true
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum Patroller-"$VERSION"-* 2>/dev/null | tee "SHA256SUMS-${VERSION}.txt" || true
  fi
)

echo
echo "✓ Release packaging complete → $DIST"
echo "  Upload zip/dmg manually on GitHub → Releases (no CI)."
echo "  Then update the Installation download links in README.md if the version changed."
