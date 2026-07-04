## 2024-05-18 - Avoid rebuilds of test list when health check updates
**Learning:** `TestExplorer` depends on `appProvider`. `appProvider` has a field `healthWarningCount`. When a background health check updates the warning count, it changes `AppState`, causing `TestExplorer` to rebuild the entire test list (which can be large and contain expansion state).
**Action:** Extract `healthWarningCount` to `healthProvider` or use a narrower selector on `appProvider` when `TestExplorer` watches it, to avoid rebuilding tests when unrelated state (like health) changes.
