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

The source currently lives in `native/ios-simulator-driver/` in a
`patrol-studio-tauri` checkout. From this repository, run:

```bash
PATROL_STUDIO_TAURI_ROOT=/path/to/patrol-studio-tauri \
  scripts/build-simulator-driver.sh
```

If both repositories are siblings, the environment variable can be omitted.
