## 2024-07-13 - [Preventing App-Wide Rebuilds with Riverpod Select]
**Learning:** Watching an entire complex provider (like `appProvider` or `settingsProvider`) at the root widget level (e.g., inside `MaterialApp`) causes the entire application to unnecessarily rebuild whenever any sub-state changes, drastically impacting performance.
**Action:** Use Riverpod's `.select(...)` modifier at the root of the app to only watch the specific fields required for routing/initialization (like `activeView` and `loaded`), isolating rebuilds to where they are actually needed.
