# Patroller

**Patroller** is Patrol Studio rebuilt as a native **Flutter desktop** app (macOS & Windows). It mirrors the Electron and Tauri editions: same layout, shortcuts, runner workflows, and data paths — so you can compare all three side by side.

## Quick start

```bash
cd ideaprojects/patroller
flutter pub get
flutter run -d macos    # or: flutter run -d windows
```

Release build:

```bash
flutter build macos
open build/macos/Build/Products/Release/Patroller.app
```

## Feature parity

| Area | Status |
|------|--------|
| Landing + recent projects | ✅ |
| Open / validate / scan project | ✅ |
| Test explorer (search, select, status) | ✅ |
| Test / Test All / Develop / Develop All / Stop | ✅ |
| Auto-boot simulator before run | ✅ |
| Live logs (batching, filters, search, export) | ✅ |
| Run history (per project) | ✅ |
| Environment health checks | ✅ |
| Settings (shared `settings.json`) | ✅ |
| Device picker + boot/shutdown | ✅ |
| Keyboard shortcuts (⌘O/R/⇧R/D/./K/F) | ✅ |
| Hierarchy inspector (XCTest driver) | 🔜 scaffolded |
| Simulator recording / replay | 🔜 scaffolded |
| External input monitor (Simulator.app) | 🔜 planned |

Patroller uses the same user-data folder as Patrol Studio:

- **macOS:** `~/Library/Application Support/Patrol Studio/`
- **Windows:** `%APPDATA%\Patrol Studio\`

Settings, history, and recent projects are shared across Electron, Tauri, and Patroller.

## Architecture

```
lib/
  models/          # Dart types (mirrors src/shared/types.ts)
  services/        # Process spawn, scanner, runner, queue, devices, health
  providers/       # Riverpod state (app, runner, logs, settings)
  features/        # UI screens matching Patrol Studio panels
  core/theme/      # obsidian / ink / pebble design tokens
```

Backend is pure Dart (`dart:io` process control) — no Electron, no Rust, no WebView.

## Requirements

- Flutter 3.3+
- Patrol CLI, Flutter/Dart (FVM paths auto-detected)
- macOS: Xcode + iOS Simulator for test runs
- Windows: test runs target macOS simulators only when connected; UI runs natively

## Compare the three editions

| | Electron | Tauri | **Patroller** |
|---|----------|-------|---------------|
| Shell | Chromium | WebView | **Flutter** |
| Backend | Node | Rust | **Dart** |
| Bundle size | ~150 MB | ~14 MB | **~44 MB** |
| Shared settings | ✅ | ✅ | ✅ |