## 2024-05-24 - Unnecessary AppShell Rebuilds
**Learning:** Watching whole complex providers like `appProvider` and `healthProvider` inside the root `AppShell` widget causes the entire app layout to rebuild on any state change (e.g., when a test file is selected, or a single test runs), leading to poor performance.
**Action:** Use Riverpod's `select` (e.g., `ref.watch(appProvider.select((a) => a.healthWarningCount))`) in layout shells to scope rebuilds only to the specific state they actually display.
