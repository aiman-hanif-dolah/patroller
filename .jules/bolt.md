## 2024-05-20 - [Optimize Riverpod watches in root layout]
**Learning:** Watching the entire state object (like `ref.watch(appProvider)`) in root components like `AppShell` causes the widget to rebuild unnecessarily when *any* state changes (e.g., test selection, test logs).
**Action:** Always use `.select()` in root layouts to extract only the needed fields and prevent excessive widget tree rebuilds.
