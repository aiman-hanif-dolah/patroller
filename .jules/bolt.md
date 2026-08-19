## 2026-07-03 - [Optimizing log filtering]
**Learning:** `sanitizeLogText` was being called multiple times per log line during rendering and filtering.
**Action:** The log text is already sanitized when received in `_sanitizeIncomingLog` in `LogNotifier` and stored as the `text` property, while the raw string is saved as `rawText`. Avoid redundant `sanitizeLogText(log.text)` in `classifyLog`, `matchesLogFilters`, and `_isCollapsibleWarningBlock`. We can just use `log.text` directly since it's already sanitized.
