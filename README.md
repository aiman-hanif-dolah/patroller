<p align="center">
  <img src="assets/branding/patroller-app-icon.jpg" alt="Patroller" width="128" height="128" style="border-radius: 24px;" />
</p>

<h1 align="center">Patroller</h1>

<p align="center">
  <strong>Open-source Flutter desktop workbench for <a href="https://patrol.leancode.co">Patrol</a> UI tests</strong><br/>
  Run, develop, record, and agent-assist Patrol flows - without living in the terminal.
</p>

<p align="center">
  <a href="https://github.com/aiman-hanif-dolah/patroller/stargazers"><img src="https://img.shields.io/github/stars/aiman-hanif-dolah/patroller?style=for-the-badge&logo=github" alt="Stars" /></a>
  <a href="https://github.com/aiman-hanif-dolah/patroller/network/members"><img src="https://img.shields.io/github/forks/aiman-hanif-dolah/patroller?style=for-the-badge&logo=github" alt="Forks" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue?style=for-the-badge" alt="License: MIT" /></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.3%2B-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" /></a>
  <a href="#platforms"><img src="https://img.shields.io/badge/platform-macOS%20%7C%20Windows-lightgrey?style=for-the-badge" alt="Platforms" /></a>
</p>

<p align="center">
  <a href="#-why-patroller">Why</a> ·
  <a href="#-features">Features</a> ·
  <a href="#installation">Installation</a> ·
  <a href="#-quick-start">Build from source</a> ·
  <a href="#-prepare-your-flutter-app-for-patrol">Patrol project setup</a> ·
  <a href="#-fork--contribute">Fork &amp; contribute</a> ·
  <a href="#-architecture">Architecture</a> ·
  <a href="#-license">License</a>
</p>

<p align="center">
  <strong>MIT licensed. Forks, issues, and pull requests are welcome.</strong><br/>
  <a href="https://github.com/aiman-hanif-dolah/patroller/fork">Fork</a> ·
  <a href="CONTRIBUTING.md">Contributing</a> ·
  <a href="https://github.com/aiman-hanif-dolah/patroller/issues/new/choose">Open an issue</a>
</p>

---

## 🎯 Why Patroller?

[Patrol](https://patrol.leancode.co) is excellent for Flutter E2E UI tests - but the day-to-day loop is still heavy: devices, `patrol test` / `patrol develop`, logs, recordings, MCP agents, and health checks scattered across terminals and IDEs.

**Patroller** is a **native Flutter desktop app** that turns that loop into a visual workbench:

| Pain | Patroller |
|------|-----------|
| Hunt for devices & boot simulators | Device picker + auto-boot |
| Re-type long `patrol` commands | One-click Test / Develop / Stop |
| Scroll raw terminal spam | Live logs with filters, search, export |
| “Did this project work last week?” | Per-project run history |
| Wire MCP for AI agents by hand | Agent workbench installs & binds MCP |
| Capture a flow as code | Record → export `patrolTest` Dart / flow editor |

Built with **pure Dart process control** - no Electron shell, no WebView tax for the main UI.

---

## 📊 HTML reports (any Flutter + Patrol project)

Patroller can generate a **self-contained HTML + CSS report** for **any** project you open — not just one app.

| How | What happens |
|-----|----------------|
| **Test All / queue finishes** | Generates the report, then shows a dialog: *“This is the generated report for the Patrol tests you ran.”* → **Open report** opens it in your browser. Toggle in Settings (default **on**). |
| **Run History** | Select a run or batch → **Export HTML report** → same open dialog |
| **CLI** | Parse existing Patrol logs offline (`--out` optional) |

Reports are stored under the Patrol Studio data folder (`…/Patrol Studio/reports/`), not Downloads, so the app can prompt you to open them immediately.

```bash
cd /path/to/patroller
dart run bin/patroller_report.dart \
  --project /path/to/your-flutter-app \
  --logs ~/Library/Logs/your-app/*.log \
  --mode mock \
  --out ./my-report.html
```

The report lists targets/suites, leaf `*_test.dart` files, scenario Pass/Fail, filters, and pass rate. Logs are parsed generically (`test result: PASSED|FAILED`, suite Successful/Failed counts).

---

## ✨ Features

- **Landing & projects** - open Flutter projects, recent list, validation
- **Test explorer** - search, multi-select, status badges
- **Runner** - Test / Test All / Develop / Develop All / Stop
- **Devices** - list, boot, shutdown; **iOS Simulator runs** (primary target today)
- **Live logs** - batching, filters, search, failed-log focus, export
- **Failure diagnosis** - maps common Patrol/tool errors to likely fixes + copyable commands
- **Run history** - retained per project
- **HTML batch reports** - after **Test All**, prompt to open the report in your browser; History export; CLI for any project’s logs
- **Environment health** - Flutter, Patrol CLI, simctl, copyable fixes, “CLI Patrol works → no extra setup” guidance
- **Recordings** - capture Simulator interactions, replay, export Patrol code *(optional)*
- **Visual flow editor** - edit steps → generate / run Patrol-oriented flows
- **Agent workbench** - install Patrol MCP + Marionette MCP on the machine, bind Cursor config, fill agent prompts *(optional)*
- **DevTools extension** - local HTTP + WebSocket API + panel (`/panel`) *(optional)*
- **Keyboard shortcuts** - ⌘O open, ⌘R test, ⇧⌘R test all, ⌘D develop, and more

> Settings and history live under the shared **Patrol Studio** data folder so Electron / Tauri / Flutter editions can coexist:
> - **macOS:** `~/Library/Application Support/Patrol Studio/`
> - **Windows:** `%APPDATA%\Patrol Studio\`

---

## 🖥️ Platforms

| Platform | App UI | Running Patrol tests |
|----------|--------|----------------------|
| **macOS** | ✅ Full | ✅ iOS Simulator (+ tooling) |
| **Windows** | ✅ Full | UI works; mobile test runs depend on your connected toolchains |

---

## Installation

No Flutter SDK is required to **run** Patroller. Download the installer we publish on GitHub Releases (built and uploaded manually - no CI).

<p align="center">
  <a href="https://github.com/aiman-hanif-dolah/patroller/releases/latest">
    <img src="https://img.shields.io/github/v/release/aiman-hanif-dolah/patroller?style=for-the-badge&label=Latest%20release" alt="Latest release" />
  </a>
  <a href="https://github.com/aiman-hanif-dolah/patroller/releases/download/v1.0.0/Patroller-1.0.0-macos-arm64.dmg">
    <img src="https://img.shields.io/badge/Download-macOS%20DMG-0A84FF?style=for-the-badge&logo=apple" alt="Download macOS DMG" />
  </a>
  <a href="https://github.com/aiman-hanif-dolah/patroller/releases/download/v1.0.0/Patroller-1.0.0-macos-arm64.zip">
    <img src="https://img.shields.io/badge/Download-macOS%20ZIP-555555?style=for-the-badge&logo=apple" alt="Download macOS ZIP" />
  </a>
  <a href="https://github.com/aiman-hanif-dolah/patroller/releases/latest">
    <img src="https://img.shields.io/badge/Download-Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Download Windows" />
  </a>
</p>

| Platform | Installer | Status |
|----------|-----------|--------|
| **macOS (Apple Silicon)** | [DMG](https://github.com/aiman-hanif-dolah/patroller/releases/download/v1.0.0/Patroller-1.0.0-macos-arm64.dmg) · [ZIP](https://github.com/aiman-hanif-dolah/patroller/releases/download/v1.0.0/Patroller-1.0.0-macos-arm64.zip) | Published on [v1.0.0](https://github.com/aiman-hanif-dolah/patroller/releases/tag/v1.0.0) |
| **Windows x64** | Portable `Patroller-*-windows-x64.zip` on [Releases](https://github.com/aiman-hanif-dolah/patroller/releases) | Build on a Windows PC and upload (see below) |

### macOS installer (current: v1.0.0)

| File | Link |
|------|------|
| **DMG (recommended)** | [Patroller-1.0.0-macos-arm64.dmg](https://github.com/aiman-hanif-dolah/patroller/releases/download/v1.0.0/Patroller-1.0.0-macos-arm64.dmg) |
| ZIP | [Patroller-1.0.0-macos-arm64.zip](https://github.com/aiman-hanif-dolah/patroller/releases/download/v1.0.0/Patroller-1.0.0-macos-arm64.zip) |
| All releases | [github.com/aiman-hanif-dolah/patroller/releases](https://github.com/aiman-hanif-dolah/patroller/releases) |

**Install steps**

1. Download the **DMG** (or ZIP) above.
2. Open the DMG and drag **Patroller** into **Applications**  
   (or unzip and move `Patroller.app` into Applications).
3. Launch **Patroller** from Launchpad or Spotlight.
4. **First open:** if macOS blocks an unsigned build, right-click **Patroller** → **Open** → **Open**, or:

   ```bash
   xattr -dr com.apple.quarantine /Applications/Patroller.app
   open -a Patroller
   ```

### Windows installer (portable zip)

Flutter cannot build Windows apps from a Mac. Produce the zip on **Windows**, then upload it to the same [Releases](https://github.com/aiman-hanif-dolah/patroller/releases) page (manual - no CI).

**If a Windows zip is already on the release**

1. Download **`Patroller-*-windows-x64.zip`** from [Releases](https://github.com/aiman-hanif-dolah/patroller/releases/latest).
2. Unzip anywhere (e.g. `%LOCALAPPDATA%\Patroller`).
3. Run **`patroller.exe`** (pin to taskbar if you like). No admin install required.

**If you need to create the Windows zip** (one-time on a Windows PC)

```powershell
git clone https://github.com/aiman-hanif-dolah/patroller.git
cd patroller
flutter config --enable-windows-desktop
.\scripts\package-windows.ps1
# Upload dist\Patroller-*-windows-x64.zip on GitHub → Releases
```

Full notes: [docs/WINDOWS_RELEASE.md](docs/WINDOWS_RELEASE.md).

**Until a zip is published**, Windows users can [build from source](#-quick-start-build-from-source):

```powershell
flutter pub get
flutter run -d windows
# or: flutter build windows --release
```

### After install: Flutter app under test

Patroller is the **workbench**. The project you open still needs Patrol configured (deps + Android `MainActivityTest` + iOS **RunnerUITests**). See [Prepare your Flutter app for Patrol](#-prepare-your-flutter-app-for-patrol).

To **run** tests from Patroller you also want:

```bash
dart pub global activate patrol_cli
patrol doctor
```

### Maintainers: rebuild and upload (local only, no CI)

```bash
# macOS → dist/Patroller-*.dmg and dist/Patroller-*.zip
./scripts/package-release.sh --macos-only

# Windows (PowerShell) → dist/Patroller-*-windows-x64.zip
.\scripts\package-windows.ps1
```

Then: **GitHub → Releases → edit/draft → Upload assets**. Update the download links in this section if the version number changes.

---

## 🚀 Quick start (build from source)

Use this if you are developing Patroller or there is no release yet for your platform.

### Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) **3.3+**
- [Patrol CLI](https://pub.dev/packages/patrol_cli) (`dart pub global activate patrol_cli`) when running tests
- macOS: Xcode + iOS Simulator for full runner workflows

### Clone & run

```bash
git clone https://github.com/aiman-hanif-dolah/patroller.git
cd patroller
flutter pub get
flutter run -d macos      # or: flutter run -d windows
```

### Local release-style build (macOS)

```bash
./scripts/package-release.sh --macos-only
open dist/Patroller-*-macos-*.dmg
# or install into /Applications:
# open build/macos/Build/Products/Release/Patroller.app
```

### Optional: reinstall helper (dev)

```bash
./scripts/reinstall-macos.sh
```

---

## 📱 Prepare your Flutter app for Patrol

Patroller runs **`patrol test` / `patrol develop`** against a **Flutter app project** you open in the workbench. The Patroller desktop app itself does **not** replace native Android/iOS wiring inside that app.

If native setup is missing, runs often fail with:

| Symptom | Usual cause |
|---------|-------------|
| `xcodebuild exited with code 70`, **Total: 0** tests | Missing or unlinked **RunnerUITests** on iOS |
| App installs but tests never start | Android instrumentation / `MainActivityTest` not wired |
| `flutter test` "works" but `patrol test` does not | Patrol requires native hosts + **patrol_cli** (not plain `flutter test`) |

Follow the official guide end-to-end:  
**[Install Patrol](https://patrol.leancode.co/documentation)**  
(match `patrol` and `patrol_cli` versions via the [compatibility table](https://patrol.leancode.co/documentation/compatibility-table).)

### 1. Shared (every project)

```bash
# On your machine
dart pub global activate patrol_cli
patrol doctor

# In the Flutter app under test
cd path/to/your_flutter_app
flutter pub add patrol --dev
flutter pub add integration_test --dev --sdk=flutter
```

In `pubspec.yaml`:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  patrol: ^4.7.0   # pin to a version compatible with your patrol_cli

patrol:
  app_name: My App
  android:
    package_name: com.example.my_app          # applicationId
  ios:
    bundle_id: com.example.myApp              # PRODUCT_BUNDLE_IDENTIFIER
  # optional:
  # test_directory: patrol_test               # default is patrol_test/
```

Put tests under `patrol_test/` (default), e.g. `patrol_test/smoke_test.dart`.  
Add `patrol_test/test_bundle.dart` to `.gitignore` (generated by Patrol).

### 2. Android native setup

Required so instrumentation can list and run Dart Patrol tests.

**`android/app/build.gradle.kts` (Kotlin DSL)** - essentials:

```kotlin
android {
    defaultConfig {
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
        testInstrumentationRunnerArguments["clearPackageData"] = "true"
    }
    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
    }
}

dependencies {
    androidTestUtil("androidx.test:orchestrator:1.5.1")
}
```

**Instrumentation test host** (package path must match your app package):

`android/app/src/androidTest/java/com/example/my_app/MainActivityTest.java`

```java
package com.example.my_app;

import androidx.test.platform.app.InstrumentationRegistry;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;
import org.junit.runners.Parameterized.Parameters;
import pl.leancode.patrol.PatrolJUnitRunner;

@RunWith(Parameterized.class)
public class MainActivityTest {
    @Parameters(name = "{0}")
    public static Object[] testCases() {
        PatrolJUnitRunner instrumentation =
                (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.setUp(MainActivity.class);
        instrumentation.waitForPatrolAppService();
        return instrumentation.listDartTests();
    }

    public MainActivityTest(String dartTestName) {
        this.dartTestName = dartTestName;
    }

    private final String dartTestName;

    @Test
    public void runDartTest() {
        PatrolJUnitRunner instrumentation =
                (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.runDartTest(dartTestName);
    }
}
```

Use Groovy `build.gradle` equivalents if your project is not on Kotlin DSL - see [Patrol Android setup](https://patrol.leancode.co/documentation).

### 3. iOS native setup (RunnerUITests)

iOS Patrol runs through a **UI Testing** target - not unit `RunnerTests`. Without this, you commonly get **0 tests** and `xcodebuild` exit **70**.

**Checklist:**

| Piece | Purpose |
|-------|---------|
| Target **`RunnerUITests`** | UI test bundle (`com.apple.product-type.bundle.ui-testing`) |
| `ios/RunnerUITests/RunnerUITests.m` | Patrol iOS runner macro |
| `ios/TestPlan.xctestplan` | Points the scheme at `RunnerUITests` |
| **Runner** scheme Test action | Includes Test Plan + `RunnerUITests` |
| `Podfile` nested target | `RunnerUITests` with `inherit! :complete` |
| Build setting `TEST_TARGET_NAME = Runner` | Host app for UI tests |
| `PRODUCT_NAME = $(TARGET_NAME)` | Avoid empty `.xctest` product names |

**`ios/RunnerUITests/RunnerUITests.m`:**

```objc
@import XCTest;
@import patrol;
@import ObjectiveC.runtime;

PATROL_INTEGRATION_TEST_IOS_RUNNER(RunnerUITests)
```

**`ios/Podfile`** (nested under `Runner`):

```ruby
target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))

  target 'RunnerTests' do
    inherit! :search_paths
  end

  target 'RunnerUITests' do
    inherit! :complete
  end
end
```

Then:

```bash
cd ios && pod install && cd ..
```

Wire **RunnerUITests** into the Xcode project and **Runner** scheme (Test Plan recommended). Official steps: [Patrol iOS setup](https://patrol.leancode.co/documentation).

### 4. Sanity-check from the terminal

With a device/simulator connected:

```bash
cd path/to/your_flutter_app
patrol test -t patrol_test/smoke_test.dart
# or
patrol develop -t patrol_test/smoke_test.dart
```

You want a non-zero **Total** and green **Successful** counts - not **Total: 0**.

### 5. Then open the project in Patroller

1. Launch Patroller → open the same Flutter app folder.  
2. Confirm **Environment health** (Flutter, Patrol CLI, simctl/adb as needed).  
3. Pick a device → select tests → **Test** / **Develop**.

Patroller assumes the app under test is already a valid Patrol project (deps + Android instrumentation + iOS **RunnerUITests**). If runs fail with native build errors, fix the Flutter app setup first using the checklist above.

### Quick project checklist

- [ ] `patrol` + `integration_test` in `dev_dependencies`
- [ ] `patrol:` section in `pubspec.yaml` (`package_name` / `bundle_id`)
- [ ] Tests under `patrol_test/` (or configured `test_directory`)
- [ ] Android: `PatrolJUnitRunner` + `MainActivityTest` + orchestrator
- [ ] iOS: **RunnerUITests** + `RunnerUITests.m` + Test Plan / scheme + Pods
- [ ] Compatible `patrol` / `patrol_cli` versions
- [ ] `patrol doctor` is clean for your platform

---

## 🤖 Agent + MCP workflow

MCP servers are **installed on your machine**, not injected into every Flutter app’s `pubspec.yaml`.

**From Patroller (recommended)**

1. Open **Agent**
2. **Install / update** Patrol MCP and Marionette MCP
3. Open a Flutter project → **Start MCP routine** (writes Cursor wrapper + merges `~/.cursor/mcp.json`)
4. Use **Agent prompt routines** (e.g. Marionette coverage) → copy prompt into Cursor

**From a terminal (equivalent)**

```bash
dart pub global activate patrol_mcp
dart pub global activate marionette_mcp
```

Patroller prepares MCP + prompts; it does **not** run your AI agent for you.

---

## 🧩 DevTools extension

Enable under **Settings → DevTools Extension** (default port `8771`).

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health` | Liveness |
| GET | `/devices` | List devices |
| POST | `/runs` | Start a run |
| POST | `/runs/<id>/stop` | Stop a run |
| GET | `/panel` | Built extension UI |
| WS | `/ws` | Logs / status stream |

Open the panel at **`http://localhost:8771/panel`** while Patroller is running.

Build / refresh panel assets:

```bash
cd devtools_extension
flutter pub get
flutter build web --release --base-href=/panel/ --no-tree-shake-icons
perl -i -pe 's|<base href="/panel/"\s*/?>|<base href="/">|' build/web/index.html
rm -rf ../extension/devtools/build
cp -R build/web ../extension/devtools/build
```

---

## 🏗️ Architecture

```text
lib/
  models/       # Domain types (settings, devices, runs, recordings)
  services/     # Process spawn, patrol runner, queue, devices, health, MCP
  providers/    # Riverpod state
  features/     # UI: landing, shell, tests, logs, agent, recordings, …
  domain/       # Pure helpers (prompts, readiness, log sanitizing)
  core/theme/   # Design tokens
  widgets/      # Shared UI
  devtools/     # Extension server glue

scripts/        # macOS reinstall, resource bundling, driver build
resources/      # Simulator driver / input-monitor assets
devtools_extension/   # Flutter web panel source
extension/devtools/   # Packaged DevTools extension (config + build)
```

**Stack:** Flutter desktop · Riverpod · `dart:io` process control · optional local shelf HTTP/WS API.

---

## 📊 Edition comparison

| | Electron | Tauri | **Patroller** |
|--|----------|-------|---------------|
| Shell | Chromium | WebView | **Flutter** |
| Backend | Node | Rust | **Dart** |
| Approx. bundle | ~150 MB | ~14 MB | **~44 MB** |
| Shared settings | ✅ | ✅ | ✅ |

---

## 🍴 Fork & contribute

Patroller is **public**, **MIT-licensed**, and **built for community use**. You are encouraged to:

- **Fork** the repo and ship your own builds or company-internal variants  
- **Open issues** for bugs, ideas, and docs gaps  
- **Send pull requests** for features, Windows packaging help, UI polish, tests  

No CLA beyond MIT. By contributing, your work is licensed under the same [MIT License](LICENSE).

### Why fork?

| You want to… | Do this |
|--------------|---------|
| Customize for your team | [Fork](https://github.com/aiman-hanif-dolah/patroller/fork) and keep a private/public copy |
| Fix a bug or add a feature | Fork → branch → PR into `main` |
| Build Windows/macOS installers | Use `scripts/package-windows.ps1` / `package-release.sh`, upload to *your* Releases if you like |
| Just try the app | [Download installers](#installation) - no need to fork |

### Fork on GitHub (recommended flow)

1. Click **[Fork](https://github.com/aiman-hanif-dolah/patroller/fork)**.
2. Clone **your** fork:

   ```bash
   git clone https://github.com/<your-username>/patroller.git
   cd patroller
   flutter pub get
   flutter run -d macos   # or: flutter run -d windows
   ```

3. Create a branch: `git checkout -b feature/your-idea`
4. Make focused changes; run `flutter test`
5. Push and open a **Pull Request** against `aiman-hanif-dolah/patroller` `main`

### Keep your fork up to date

```bash
git remote add upstream https://github.com/aiman-hanif-dolah/patroller.git
git fetch upstream
git checkout main
git merge upstream/main   # or: git rebase upstream/main
```

### Good first contributions

- Windows portable zip packaging / docs  
- UI accessibility and polish  
- Health checks for more toolchains (FVM, asdf, puro)  
- Recording export and flow-editor edge cases  
- Examples of Patrol project layout  

Full guide: **[CONTRIBUTING.md](CONTRIBUTING.md)**  
Issue / PR templates: `.github/`

<p align="center">
  <a href="https://github.com/aiman-hanif-dolah/patroller/fork">
    <img src="https://img.shields.io/badge/Fork%20this%20repo-181717?style=for-the-badge&logo=github" alt="Fork this repo" />
  </a>
  <a href="CONTRIBUTING.md">
    <img src="https://img.shields.io/badge/Read%20CONTRIBUTING-2ea44f?style=for-the-badge&logo=github" alt="Contributing" />
  </a>
  <a href="https://github.com/aiman-hanif-dolah/patroller/issues/new/choose">
    <img src="https://img.shields.io/badge/Open%20an%20issue-c41e3a?style=for-the-badge&logo=github" alt="Open an issue" />
  </a>
  <a href="https://github.com/aiman-hanif-dolah/patroller/stargazers">
    <img src="https://img.shields.io/badge/Star%20on%20GitHub-e3b341?style=for-the-badge&logo=github" alt="Star" />
  </a>
</p>

---

## 🧪 Tests

```bash
flutter test
```

---

## 🔗 Related

- [Patrol](https://patrol.leancode.co) - Flutter-first UI testing
- [patrol](https://pub.dev/packages/patrol) / [patrol_cli](https://pub.dev/packages/patrol_cli) on pub.dev
- LeanCode’s Patrol ecosystem (MCP, finders, docs)

---

## 📄 License

Released under the **[MIT License](LICENSE)** - free to use, fork, modify, and distribute.

```
Copyright (c) 2026 Aiman Hanif
```

---

<p align="center">
  Made for Flutter teams who live in Patrol every day.<br/>
  <sub>Not affiliated with LeanCode; Patrol is a trademark of its respective owners.</sub>
</p>
