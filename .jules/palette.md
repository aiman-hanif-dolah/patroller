## 2024-07-26 - Add Loading States to Run Toolbar Buttons
**Learning:** Added loading indicators (`CircularProgressIndicator`) to action buttons in the run toolbar when they are active. This gives immediate visual feedback during async operations, replacing static icons that didn't show progress.
**Action:** When creating action buttons that trigger async work, especially in a toolbar, always provide an inline loading state to improve feedback.
