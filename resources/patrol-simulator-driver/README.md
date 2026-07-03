# Patrol Simulator Driver

First-party XCTest runner used by Patroller and Patrol Studio for iOS Simulator
control: screenshots, taps, swipes, text input, and view-hierarchy inspection.

## Layout

```
resources/patrol-simulator-driver/
├── VERSION
└── simulator/
    ├── patrol-simulator-driver-config.xctestrun
    └── Debug-iphonesimulator/
        ├── PatrolSimulatorDriver.zip
        └── PatrolSimulatorDriverUITests-Runner.zip
```

## Rebuild

From `patrol-studio-tauri`:

```bash
scripts/build-simulator-driver.sh
```

Sources live in `native/ios-simulator-driver/`.