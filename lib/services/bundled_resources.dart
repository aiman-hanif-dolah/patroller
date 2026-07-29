import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves bundled native resource roots (simulator driver, input monitor).
Directory resolveBundledResourceRoot(String name) {
  final envKey = switch (name) {
    'patrol-simulator-driver' => 'PATROL_SIMULATOR_DRIVER_ROOT',
    'simulator-input-monitor' => 'PATROL_SIMULATOR_INPUT_MONITOR_ROOT',
    _ => 'PATROL_RESOURCE_${name.toUpperCase().replaceAll('-', '_')}',
  };
  final envPath = Platform.environment[envKey];
  if (envPath != null && envPath.isNotEmpty) {
    final candidate = Directory(envPath);
    if (candidate.existsSync()) return candidate;
  }

  final executable = Platform.resolvedExecutable;
  for (final base in [
    // macOS app bundle: Patroller.app/Contents/MacOS/Patroller.
    p.join(p.dirname(executable), '..', 'Resources', name),
    // Windows/Linux portable package: resources next to the executable.
    p.join(p.dirname(executable), 'resources', name),
  ]) {
    if (Directory(base).existsSync()) {
      return Directory(p.normalize(base));
    }
  }

  final cwd = Directory.current.path;
  for (final base in [
    p.join(cwd, 'resources', name),
    p.join(cwd, '..', 'resources', name),
  ]) {
    if (Directory(base).existsSync()) {
      return Directory(p.normalize(base));
    }
  }

  return Directory(p.join(cwd, 'resources', name));
}

File? resolveBundledBinary(String folderName, String binaryName) {
  final envOverride = Platform.environment['PATROL_SIMULATOR_INPUT_MONITOR'];
  if (folderName == 'simulator-input-monitor' &&
      envOverride != null &&
      envOverride.isNotEmpty) {
    final file = File(envOverride);
    if (file.existsSync()) return file;
  }

  final root = resolveBundledResourceRoot(folderName);
  final candidate = File(p.join(root.path, binaryName));
  if (candidate.existsSync()) return candidate;
  return null;
}
