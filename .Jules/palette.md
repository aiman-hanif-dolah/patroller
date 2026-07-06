## 2024-05-14 - Search Field UX Enhancement
**Learning:** Adding a clear button to search fields is a high-value micro-UX improvement that reduces user friction when clearing a query. The codebase utilizes a custom `AccessibleIconButton` wrapper for semantics.
**Action:** Use `AccessibleIconButton` instead of a plain `IconButton` for new UI icon buttons to maintain the accessibility standards across the app. Ensure `TextEditingController` instances are initialized in a state class rather than within `build()` to prevent resetting the cursor position on rebuild.
