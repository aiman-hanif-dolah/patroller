## 2024-05-18 - Avoid instantiating TextEditingController in build()
**Learning:** Instantiating `TextEditingController(text: ...)` directly inside the `build()` method recreates the controller on every widget rebuild, resetting the user's cursor position.
**Action:** When a TextField needs to be initialized with a value but is also editable, manage the `TextEditingController` statefully (e.g. initialize in `initState`, dispose in `dispose`).
