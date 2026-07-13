## 2024-05-24 - Riverpod State Selection
**Learning:** Watching entire large state objects (like `AppState` via `ref.watch(appProvider)`) at root-level widgets (like `AppShell` or `RecordingsPanel`) causes unnecessary and expensive UI rebuilds when unrelated state fields change.
**Action:** Always use `ref.watch(provider.select(...))` when only specific fields from a large state object are needed, especially in large foundational widgets.
