# Patroller DevTools extension

Flutter web app that powers the **Patroller** tab in Flutter DevTools and the
panel served by Patroller at `/panel`.

## Package layout

| Path | Role |
|------|------|
| `devtools_extension/` (this package) | Extension Flutter web **source** |
| `../extension/devtools/config.yaml` | DevTools discovery metadata |
| `../extension/devtools/build/` | Prebuilt web assets shipped with Patroller |

This follows the [companion extension](https://docs.flutter.dev/tools/devtools/custom-tool) layout: source lives beside the package that ships `extension/devtools/`.

## Develop

```bash
cd devtools_extension
flutter pub get
# Simulated DevTools host (hot reload friendly):
flutter run -d chrome --dart-define=use_simulated_environment=true
# Or point at a running Patroller extension server:
flutter run -d chrome --dart-define=PATROLLER_URL=http://localhost:8771
```

## Build into `extension/devtools/build`

```bash
cd devtools_extension
flutter pub get
flutter build web --release \
  --base-href=/panel/ \
  --no-tree-shake-icons
# Normalize base href to "/" for DevTools package discovery (DDS rewrites "/").
# Patroller re-applies /panel/ when serving HTML at http://localhost:<port>/panel.
perl -i -pe 's|<base href="/panel/"\s*/?>|<base href="/">|' build/web/index.html
rm -rf ../extension/devtools/build
cp -R build/web ../extension/devtools/build
```

Or use the official helper (builds with base `/`; Patroller still rewrites for `/panel`):

```bash
dart run devtools_extensions build_and_copy \
  --source=. \
  --dest=../extension/devtools
```

Validate packaging:

```bash
dart run devtools_extensions validate --package=..
```

`scripts/reinstall-macos.sh` runs the `--base-href=/panel/` build + normalize + copy automatically.

## Load modes

See the root [README.md](../README.md#devtools-extension) for:

1. **Served from Patroller** at `http://localhost:8771/panel`
2. **As a Flutter DevTools extension** via path/`dev_dependency` discovery
