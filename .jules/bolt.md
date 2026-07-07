## 2024-07-05 - Avoid root widget rebuilds in Riverpod with select()
**Learning:** Watching large providers (like `appProvider`) directly in root or high-level widgets (like `AppShell`) causes unnecessary re-renders of the entire widget tree when unrelated state changes (like test results or queue status).
**Action:** Always prefer `ref.watch(provider.select((state) => state.specificField))` for root components to isolate rebuilds strictly to the fields they consume.
