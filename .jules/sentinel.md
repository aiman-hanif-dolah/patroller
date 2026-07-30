## 2025-02-14 - AppleScript Command Injection in Dart
**Vulnerability:** AppleScript command injection in `simulator_window_bounds.dart` via `osascript`. The `deviceName` parameter was interpolated into an AppleScript string without properly escaping backslashes, only double quotes.
**Learning:** When passing user-controlled strings to AppleScript via `osascript`, escaping double quotes (`"`) is insufficient if backslashes (`\`) are not escaped first. An attacker can use a trailing backslash to escape the escaped double quote, breaking out of the string context and injecting arbitrary AppleScript commands.
**Prevention:** Always sanitize strings destined for AppleScript string literals by first escaping backslashes (`r'\'` to `r'\\'`), and *then* escaping double quotes (`"` to `r'\"'`).
