import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/models.dart';

final _namePattern = RegExp(r'^name:\s*(.+)$', multiLine: true);
final _patrolTestDirPattern = RegExp(
  r'patrol:\s*\n\s+test_dir:\s*(.+)$',
  multiLine: true,
);

const _patrolPatterns = <String>[
  'patrol:',
  'patrol_finders:',
  'patrol_cli:',
  'patrol_test:',
];

ProjectMetadata validateProject(String projectPath) {
  final pubspecPath = p.join(projectPath, 'pubspec.yaml');
  final hasPubspecYaml = File(pubspecPath).existsSync();
  final now = DateTime.now().toUtc().toIso8601String();

  if (!hasPubspecYaml) {
    return ProjectMetadata(
      projectPath: projectPath,
      projectName: p.basename(projectPath),
      hasPubspecYaml: false,
      hasPatrol: false,
      patrolTestDir: 'patrol_test',
      lastOpened: now,
    );
  }

  final pubspecContent = File(pubspecPath).readAsStringSync();
  return ProjectMetadata(
    projectPath: projectPath,
    projectName: _extractProjectName(pubspecContent, projectPath),
    hasPubspecYaml: true,
    hasPatrol: _detectPatrol(pubspecContent),
    patrolTestDir: _detectPatrolTestDir(pubspecContent),
    lastOpened: now,
  );
}

String _extractProjectName(String pubspecContent, String projectPath) {
  final match = _namePattern.firstMatch(pubspecContent);
  if (match != null) {
    final name = match.group(1)?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
  }
  return p.basename(projectPath);
}

bool _detectPatrol(String pubspecContent) =>
    _patrolPatterns.any(pubspecContent.contains);

String _detectPatrolTestDir(String pubspecContent) {
  final match = _patrolTestDirPattern.firstMatch(pubspecContent);
  if (match != null) {
    var testDir = match.group(1)?.trim() ?? '';
    if ((testDir.startsWith("'") && testDir.endsWith("'")) ||
        (testDir.startsWith('"') && testDir.endsWith('"'))) {
      testDir = testDir.substring(1, testDir.length - 1);
    }
    if (testDir.isNotEmpty) {
      return testDir;
    }
  }
  return 'patrol_test';
}

String readFileContent(String filePath) {
  try {
    return File(filePath).readAsStringSync();
  } catch (_) {
    return '';
  }
}