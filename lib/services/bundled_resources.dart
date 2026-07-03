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
  final bundleResources = p.join(
    p.dirname(executable),
    '..',
    'Resources',
    name,
  );
  if (Directory(bundleResources).existsSync()) {
    return Directory(p.normalize(bundleResources));
  }

  final cwd = Directory.current.path;
  for (final base in [
    p.join(cwd, 'resources', name),
    p.join(cwd, '..', 'resources', name),
    p.join(cwd, '..', 'patrol-studio-tauri', 'resources', name),
    p.join(cwd, '..', 'ideaprojects', 'patrol-studio-tauri', 'resources', name),
    '/Users/ahdaiman/ideaprojects/patrol-studio-tauri/resources/$name',
    '/Users/ahdaiman/IdeaProjects/patrol-studio-tauri/resources/$name',
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