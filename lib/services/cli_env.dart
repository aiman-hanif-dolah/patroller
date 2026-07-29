import 'dart:io';

import 'package:path/path.dart' as p;

String? _augmentedPathCache;
String? _developerDirCache;

String? userHomeDirectory([Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  for (final key in ['HOME', 'USERPROFILE']) {
    final value = env[key]?.trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

String pubCacheBinDirectory({
  Map<String, String>? environment,
  bool? isWindows,
}) {
  final env = environment ?? Platform.environment;
  final configured = env['PUB_CACHE']?.trim();
  if (configured != null && configured.isNotEmpty) {
    return p.join(configured, 'bin');
  }

  final windows = isWindows ?? Platform.isWindows;
  if (windows) {
    final localAppData = env['LOCALAPPDATA']?.trim();
    if (localAppData != null && localAppData.isNotEmpty) {
      return p.join(localAppData, 'Pub', 'Cache', 'bin');
    }
  }

  final home = userHomeDirectory(env);
  return p.join(home ?? '.', '.pub-cache', 'bin');
}

/// Common bin directories for Flutter/Dart/Patrol tooling.
List<String> developerToolBinDirs() {
  final home = userHomeDirectory() ?? '.';
  final dirs = <String>[
    p.join(home, 'develop', 'fvm', 'default', 'bin'),
    p.join(home, 'fvm', 'default', 'bin'),
    p.join(home, '.fvm', 'default', 'bin'),
    p.join(home, 'develop', 'flutter', 'bin'),
    p.join(home, 'flutter', 'bin'),
    pubCacheBinDirectory(),
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

  if (Platform.isMacOS) {
    for (final systemPath in [
      p.join('/usr', 'bin', candidate),
      p.join('/Applications', 'Xcode.app', 'Contents', 'Developer', 'usr', 'bin', candidate),
    ]) {
      if (File(systemPath).existsSync() && isTrustedExecutablePath(systemPath)) {
        return systemPath;
      }
    }
  }

  for (final dir in developerToolBinDirs()) {
    final resolved = _executableIn(dir, candidate);
    if (resolved != null) return resolved;
  }

  final separator = Platform.isWindows ? ';' : ':';
  for (final dir in (Platform.environment['PATH'] ?? '').split(separator)) {
    if (dir.isEmpty) continue;
    final resolved = _executableIn(dir, candidate);
    if (resolved != null) return resolved;
  }

  return candidate;
}

String? _executableIn(String directory, String name) {
  final full = p.join(directory, name);
  final candidates = Platform.isWindows && p.extension(full).isEmpty
      ? ['$full.exe', '$full.cmd', '$full.bat', full]
      : [full];
  for (final candidate in candidates) {
    if (File(candidate).existsSync() && isTrustedExecutablePath(candidate)) {
      return candidate;
    }
  }
  return null;
}

String? _resolveDeveloperDir(Map<String, String> env) {
  if (!Platform.isMacOS) return null;
  try {
    final xcodeSelect = resolveExecutable('xcode-select');
    final result = Process.runSync(
      xcodeSelect,
      const ['-p'],
      environment: env,
    );
    if (result.exitCode == 0) {
      final dir = '${result.stdout}'.trim();
      if (dir.isNotEmpty) return dir;
    }
  } catch (_) {}
  return null;
}

/// Spawn/exec env with an augmented PATH for child processes.
Map<String, String> developerToolEnv() {
  final env = Map<String, String>.from(Platform.environment);
  env['PATH'] = augmentedDeveloperPath();
  _developerDirCache ??= _resolveDeveloperDir(env);
  final developerDir = _developerDirCache;
  if (developerDir != null && developerDir.isNotEmpty) {
    env['DEVELOPER_DIR'] = developerDir;
  }
  return env;
}

/// Clears cached PATH (useful after settings change).
void clearAugmentedPathCache() {
  _augmentedPathCache = null;
  _developerDirCache = null;
}
