import 'dart:io';

/// Opens a local HTML report in the default browser / viewer.
Future<void> openHtmlReport(String path) async {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('Report file not found: $path');
  }

  if (Platform.isMacOS) {
    final result = await Process.run('open', [path]);
    if (result.exitCode != 0) {
      throw StateError(
        (result.stderr as String?)?.trim().isNotEmpty == true
            ? result.stderr as String
            : 'Failed to open report (exit ${result.exitCode})',
      );
    }
    return;
  }

  if (Platform.isWindows) {
    final result = await Process.run(
      'cmd',
      ['/c', 'start', '', path],
      runInShell: true,
    );
    if (result.exitCode != 0) {
      throw StateError(
        (result.stderr as String?)?.trim().isNotEmpty == true
            ? result.stderr as String
            : 'Failed to open report (exit ${result.exitCode})',
      );
    }
    return;
  }

  final result = await Process.run('xdg-open', [path]);
  if (result.exitCode != 0) {
    throw StateError(
      (result.stderr as String?)?.trim().isNotEmpty == true
          ? result.stderr as String
          : 'Failed to open report (exit ${result.exitCode})',
    );
  }
}

/// Reveals the report file in Finder / Explorer when supported.
Future<void> revealHtmlReport(String path) async {
  if (Platform.isMacOS) {
    await Process.run('open', ['-R', path]);
    return;
  }
  if (Platform.isWindows) {
    await Process.run(
      'explorer',
      ['/select,', path.replaceAll('/', '\\')],
    );
    return;
  }
  // Linux: open parent directory
  final parent = File(path).parent.path;
  await Process.run('xdg-open', [parent]);
}
