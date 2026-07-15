## 2024-07-15 - [Riverpod `.select()` Optimization]
**Learning:** In Riverpod, watching entire state objects in complex widgets (like `WorkflowStatusStrip`) causes excessive unnecessary rebuilds when unrelated state changes. Use `.select()` to scope rebuilds only to the specific properties that the widget needs to render.
**Action:** Use `ref.watch(provider.select((state) => state.property))` instead of `ref.watch(provider)` whenever only specific properties are needed, particularly for large objects like `appProvider` and `runnerProvider`.
