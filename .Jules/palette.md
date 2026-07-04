## 2024-05-18 - Icon-Only Button Tooltips
**Learning:** In Flutter, `IconButton`s without tooltips lack semantic labels for screen readers and visible hints for mouse users.
**Action:** Always verify that `IconButton`s have a `tooltip` parameter set to provide both visual and accessible labels, especially in dense panels like `test_explorer` and `run_history`.
