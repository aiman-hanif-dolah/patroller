import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/models.dart';
import 'dart_parser.dart';

const _ignoredFolders = <String>{
  '.git',
  '.dart_tool',
  'build',
  'ios/Pods',
  'android/.gradle',
  'node_modules',
  'coverage',
  '.melos_tool',
  '.fvm',
  'generated',
  'macos/Flutter/ephemeral',
  '.idea',
  '.vscode',
  'Pods',
};

bool _shouldIgnore(String dirName) =>
    _ignoredFolders.contains(dirName) || dirName.startsWith('.');

Future<List<TestFile>> scanTestFiles(String projectPath, String testDir) async {
  final testDirPath = Directory(p.join(projectPath, testDir));
  if (!testDirPath.existsSync()) {
    return [];
  }

  final candidates = <_ScanCandidate>[];
  _collectTestFilePaths(testDirPath, projectPath, candidates);

  if (candidates.isEmpty) {
    return [];
  }

  final files = await Future.wait(candidates.map(_buildTestFile));
  final results = files.whereType<TestFile>().toList()
    ..sort((a, b) => a.relativePath.compareTo(b.relativePath));
  return results;
}

class _ScanCandidate {
  _ScanCandidate({
    required this.fullPath,
    required this.relativePath,
    required this.fileName,
  });

  final String fullPath;
  final String relativePath;
  final String fileName;
}

void _collectTestFilePaths(
  Directory dirPath,
  String projectPath,
  List<_ScanCandidate> results,
) {
  late final List<FileSystemEntity> entries;
  try {
    entries = dirPath.listSync(followLinks: false);
  } catch (_) {
    return;
  }

  for (final entry in entries) {
    final fileName = p.basename(entry.path);
    if (entry is Directory) {
      if (!_shouldIgnore(fileName)) {
        _collectTestFilePaths(entry, projectPath, results);
      }
      continue;
    }

    if (entry is! File || !fileName.endsWith('_test.dart')) {
      continue;
    }

    final relativePath = p
        .relative(entry.path, from: projectPath)
        .replaceAll('\\', '/');

    results.add(
      _ScanCandidate(
        fullPath: entry.path,
        relativePath: relativePath,
        fileName: fileName,
      ),
    );
  }
}

Future<TestFile?> _buildTestFile(_ScanCandidate candidate) async {
  final file = File(candidate.fullPath);
  if (!file.existsSync()) return null;

  try {
    final stats = await file.stat();
    final parsedTests = parseTestFile(candidate.fullPath);
    final lastModified = stats.modified.toUtc().toIso8601String();
    var folderPath = p.dirname(candidate.relativePath).replaceAll('\\', '/');
    if (folderPath.startsWith('patrol_test/')) {
      folderPath = folderPath.substring('patrol_test/'.length);
    } else if (folderPath == 'patrol_test') {
      folderPath = '';
    }
    final normalizedFolder = folderPath.isEmpty ? '' : folderPath;

    return TestFile(
      absolutePath: candidate.fullPath,
      relativePath: candidate.relativePath,
      fileName: candidate.fileName,
      folderPath: normalizedFolder,
      fileSize: stats.size,
      lastModified: lastModified,
      detectedTestCount: parsedTests.length,
      detectedGroups: const [],
      detectedTests: parsedTests,
      lastRunStatus: TestStatus.idle,
    );
  } catch (_) {
    return null;
  }
}