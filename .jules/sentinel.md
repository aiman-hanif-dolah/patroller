## 2026-07-04 - Command Injection in AppleScript
**Vulnerability:** Command injection via osascript parameter
**Learning:** AppleScript evaluation with string concatenation allows escaping from the string context if inputs aren't properly escaped (both \ and " need escaping).
**Prevention:** Always escape backslashes before escaping quotes in AppleScript string templates.
