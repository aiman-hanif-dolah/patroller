## 2026-07-14 - Inline loading states for async operations
**Learning:** Adding a small loading state inside buttons during async operations without a layout shift improves the overall UX. We need to wrap `CircularProgressIndicator(strokeWidth: 2)` inside a `SizedBox(width: 14, height: 14)` to match the typical icon size in the app.
**Action:** Always prefer using inline loading indicators (sized appropriately) in buttons for actions that perform network or file system operations to keep the UI smooth and avoid jank.
