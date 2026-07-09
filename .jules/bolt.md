## 2024-05-24 - Prevent excessive AppShell rebuilds
**Learning:** `ref.watch(appProvider)` inside the `AppShell` widget rebuilds the entire shell for ANY state change (e.g., changing selected test case, running status) causing a significant performance drop.
**Action:** Always prefer `ref.watch(provider.select(...))` to extract only the state values you care about.
