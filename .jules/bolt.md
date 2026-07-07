## 2024-05-24 - Unnecessary Rebuilds via Riverpod Provider Over-watching
**Learning:** Watching entire complex Riverpod state objects (like `appProvider`, `runnerProvider`, `settingsProvider`) and then accessing a single property (e.g. `ref.watch(appProvider).activeView`) causes root widgets like `MaterialApp` to rebuild on *any* state change, degrading performance.
**Action:** Use `.select()` (e.g. `ref.watch(appProvider.select((state) => state.activeView))`) to watch only the required fields and prevent unnecessary widget rebuilds.
