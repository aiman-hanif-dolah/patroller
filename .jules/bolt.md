## 2024-07-08 - Riverpod Performance Anti-pattern

**Learning:** Watching complex state objects like `appProvider` or `settingsProvider` in top-level layout widgets (e.g., `AppShell`, `MaterialApp`) causes unnecessary full-app rebuilds whenever high-frequency fields (like `isScanning`, `selectedTestCase`, `loaded`) change.
**Action:** Always use `.select()` in Riverpod (e.g., `ref.watch(appProvider.select((s) => s.specificField))`) for layout or root widgets to watch only the fields actually needed by that specific widget.
