import 'dart:convert';

String sanitizeRecordingImportError(Object error) {
  final message = error.toString();
  if (message.contains('invalid') || message.contains('Invalid')) {
    return 'Recording JSON is invalid.';
  }
  if (message.contains('unsupported action')) {
    return message;
  }
  if (message.contains('environment profile')) {
    return 'Recording JSON has an invalid environment profile.';
  }
  return message.isEmpty ? 'Failed to import recording.' : message;
}

({bool ok, String message}) validateRecordingImportText(String content) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) {
    return (ok: false, message: 'Paste exported recording JSON first.');
  }
  try {
    final parsed = jsonDecode(trimmed);
    if (parsed is! Map<String, dynamic>) {
      return (ok: false, message: 'Recording JSON is invalid.');
    }
    if (parsed.containsKey('json') && parsed['json'] is String) {
      jsonDecode(parsed['json'] as String);
    }
    return (ok: true, message: '');
  } catch (_) {
    return (ok: false, message: 'Recording JSON is invalid.');
  }
}