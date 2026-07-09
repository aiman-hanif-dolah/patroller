## 2024-05-15 - AppleScript Command Injection in Dart
**Vulnerability:** Command injection in `osascript` calls via unescaped backslashes in `deviceName`.
**Learning:** Only escaping quotes (`"`) is insufficient. An attacker could pass a string with backslashes to escape the quote being inserted by the interpolation, breaking out of the string context.
**Prevention:** Always escape backslashes first (`.replaceAll(r'\', r'\\')`), then escape quotes when interpolating user-controlled strings into AppleScript evaluated via `osascript`.
