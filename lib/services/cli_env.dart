import 'dart:io';

import 'package:path/path.dart' as p;

String? _augmentedPathCache;

/// Common bin directories for Flutter/Dart/Patrol tooling.
List<String> developerToolBinDirs() {
  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '.';
  final dirs = <String>[
    p.join(home, 'develop', 'fvm', 'default', 'bin'),
    p.join(home, 'fvm', 'default', 'bin'),
    p.join(home, '.fvm', 'default', 'bin'),
    p.join(home, 'develop', 'flutter', 'bin'),
    p.join(home, 'flutter', 'bin'),
    p.join(home, '.pub-cache', 'bin'),
    if (Platform.isMacOS) '/opt/homebrew/bin',
    if (Platform.isMacOS) '/opt/homebrew/sbin',
    '/usr/local/bin',
    if (!Platform.isWindows) '/usr/bin',
    p.join(home, '.local', 'bin'),
  ];

  if (Platform.isMacOS) {
    final pyRoot = Directory(p.join(home, 'Library', 'Python'));
    if (pyRoot.existsSync()) {
      for (final entity in pyRoot.listSync()) {
        if (entity is Directory) {
          dirs.add(p.join(entity.path, 'bin'));
        }
      }
    }
  }

  return dirs;
}

/// PATH merged with developer tool bin directories (cached).
String augmentedDeveloperPath() {
  if (_augmentedPathCache != null) {
    return _augmentedPathCache!;
  }

  final separator = Platform.isWindows ? ';' : ':';
  final existing = Platform.environment['PATH'] ?? '';
  final merged = <String>[
    ...developerToolBinDirs(),
    ...existing.split(separator).where((s) => s.isNotEmpty),
  ];
  final unique = <String>{};
  final ordered = <String>[];
  for (final entry in merged) {
    if (unique.add(entry)) {
      ordered.add(entry);
    }
  }

  _augmentedPathCache = ordered.join(separator);
  return _augmentedPathCache!;
}

/// Reject temp-dir paths left by dev/test mocks.
bool isTrustedExecutablePath(String executablePath) {
  final resolved = p.normalize(p.absolute(executablePath));
  final tmpDir = p.normalize(p.absolute(Directory.systemTemp.path));
  return resolved != tmpDir && !resolved.startsWith('$tmpDir${p.separator}');
}

/// Normalize a user-configured CLI path.
String sanitizeConfiguredExecutablePath(String? configured, String defaultName) {
  final trimmed = configured?.trim();
  final candidate = (trimmed == null || trimmed.isEmpty) ? defaultName : trimmed;

  if (!p.isAbsolute(candidate) && !candidate.contains(Platform.pathSeparator)) {
    return candidate;
  }

  final file = File(candidate);
  if (file.existsSync() && isTrustedExecutablePath(candidate)) {
    return candidate;
  }
  return defaultName;
}

/// Resolve an executable to an absolute path when possible.
String resolveExecutable(String name, {String? configuredPath}) {
  final candidate = sanitizeConfiguredExecutablePath(configuredPath, name);

  if (p.isAbsolute(candidate) || candidate.contains(Platform.pathSeparator)) {
    final file = File(candidate);
    if (file.existsSync() && isTrustedExecutablePath(candidate)) {
      return candidate;
    }
  }

  for (final dir in developerToolBinDirs()) {
    final full = p.join(dir, candidate);
    if (Platform.isWindows && !full.toLowerCase().endsWith('.exe')) {
      final withExe = '$full.exe';
      if (File(withExe).existsSync()) {
        return withExe;
      }
    }
    if (File(full).existsSync()) {
      return full;
    }
  }

  final separator = Platform.isWindows ? ';' : ':';
  for (final dir in (Platform.environment['PATH'] ?? '').split(separator)) {
    if (dir.isEmpty) continue;
    final full = p.join(dir, candidate);
    if (Platform.isWindows && !full.toLowerCase().endsWith('.exe')) {
      final withExe = '$full.exe';
      if (File(withExe).existsSync()) {
        return withExe;
      }
    }
    if (File(full).existsSync()) {
      return full;
    }
  }

  return candidate;
}

/// Spawn/exec env with an augmented PATH for child processes.
Map<String, String> developerToolEnv() {
  final env = Map<String, String>.from(Platform.environment);
  env['PATH'] = augmentedDeveloperPath();
  return env;
}

/// Clears cached PATH (useful after settings change).
void clearAugmentedPathCache() {
  _augmentedPathCache = null;
}