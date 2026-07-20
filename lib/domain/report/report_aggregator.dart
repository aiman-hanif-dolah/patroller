import 'dart:io';

import 'package:path/path.dart' as p;

import '../../models/models.dart';
import '../../services/dart_parser.dart';
import 'patrol_log_parser.dart';
import 'report_models.dart';

/// Builds a [BatchReport] from run records, optional leaf inventory, and logs.
class ReportAggregator {
  ReportAggregator({PatrolLogParser? parser})
      : _parser = parser ?? PatrolLogParser();

  final PatrolLogParser _parser;

  BatchReport fromRunRecords({
    required String projectPath,
    required String projectName,
    required List<RunRecord> records,
    List<String>? leafRelativePaths,
    Map<String, List<String>>? declaredNamesByRelativePath,
    String? queueLabel,
    String? queueId,
    String? device,
    String? runMode,
  }) {
    final targets = <TargetResult>[];
    final allScenarios = <ScenarioResult>[];
    // Direct leaf assignment when each run targeted a concrete *_test.dart leaf
    final directByRel = <String, List<ScenarioResult>>{};

    for (final record in records) {
      if (record.isQueueSummary == true) continue;

      final log = _logFor(record);
      final label = _targetLabel(record);
      final source = record.targetFile != null
          ? p.basename(record.targetFile!)
          : record.runId;
      final scenarios = _parser.parseScenarios(
        log,
        suiteOrTarget: label,
        sourceLog: source,
      );
      allScenarios.addAll(scenarios);

      final rel = _relativeTarget(projectPath, record.targetFile);
      if (rel != null &&
          rel.endsWith('_test.dart') &&
          !rel.contains('/suite/') &&
          !rel.startsWith('suite/')) {
        directByRel.putIfAbsent(rel, () => []).addAll(scenarios);
      }

      final counts = _parser.parseSuiteCounts(log);
      var passed = counts?.passed ??
          scenarios.where((s) => s.isPassed).length;
      var failed = counts?.failed ??
          scenarios.where((s) => s.isFailed).length;

      // Fall back to run exit status when log has no scenario detail.
      if (passed == 0 && failed == 0) {
        if (record.status == RunRecordStatus.passed) {
          passed = 1;
        } else if (record.status == RunRecordStatus.failed ||
            record.status == RunRecordStatus.error) {
          failed = 1;
        } else if (record.status == RunRecordStatus.skipped ||
            record.status == RunRecordStatus.cancelled) {
          // leave zeros
        }
      }

      targets.add(
        TargetResult(
          label: label,
          passed: passed,
          failed: failed,
          total: passed + failed,
          sourceLog: source,
          targetFile: record.targetFile,
          exitCode: record.exitCode,
          runStatus: record.status.toJson(),
        ),
      );
    }

    // Only leaves that participated in THIS batch of records — never the whole
    // project inventory (that would look like "old runs" / Not run noise).
    final runLeafPaths = <String>{
      ...directByRel.keys,
      for (final r in records)
        if (r.isQueueSummary != true)
          if (_relativeTarget(projectPath, r.targetFile) case final rel?)
            if (rel.endsWith('_test.dart') &&
                !rel.contains('/suite/') &&
                !rel.startsWith('suite/'))
              rel,
    };

    final leafPaths = (leafRelativePaths != null && leafRelativePaths.isNotEmpty)
        ? leafRelativePaths
        : (runLeafPaths.toList()..sort());

    final leaves = _mapLeaves(
      projectPath: projectPath,
      leafRelativePaths: leafPaths,
      scenarios: allScenarios,
      declaredNamesByRelativePath: declaredNamesByRelativePath ??
          _loadDeclaredNames(projectPath, leafPaths),
      directByRel: directByRel,
      onlyRanLeaves: leafRelativePaths == null,
    );

    return BatchReport(
      projectName: projectName,
      projectPath: projectPath,
      generatedAt: DateTime.now(),
      targets: targets,
      leaves: leaves,
      scenarios: allScenarios,
      device: device ??
          () {
            for (final r in records) {
              final d = r.selectedDevice;
              if (d != null && d.isNotEmpty) return d;
            }
            return null;
          }(),
      runMode: runMode ??
          (records.isNotEmpty ? records.first.runMode.toJson() : null),
      queueLabel: queueLabel,
      queueId: queueId,
    );
  }

  /// Aggregate from raw log files (CLI path).
  BatchReport fromLogFiles({
    required String projectPath,
    required String projectName,
    required List<File> logFiles,
    List<String>? leafRelativePaths,
    String? device,
    String? runMode,
  }) {
    final targets = <TargetResult>[];
    final allScenarios = <ScenarioResult>[];

    for (final file in logFiles) {
      if (!file.existsSync()) continue;
      final log = file.readAsStringSync();
      final label = p.basenameWithoutExtension(file.path);
      final scenarios = _parser.parseScenarios(
        log,
        suiteOrTarget: label,
        sourceLog: p.basename(file.path),
      );
      allScenarios.addAll(scenarios);
      final counts = _parser.parseSuiteCounts(log);
      final passed =
          counts?.passed ?? scenarios.where((s) => s.isPassed).length;
      final failed =
          counts?.failed ?? scenarios.where((s) => s.isFailed).length;
      targets.add(
        TargetResult(
          label: label,
          passed: passed,
          failed: failed,
          total: passed + failed,
          sourceLog: p.basename(file.path),
        ),
      );
    }

    final leaves = _mapLeaves(
      projectPath: projectPath,
      leafRelativePaths: leafRelativePaths ??
          _discoverLeaves(projectPath, preferredTestDir: 'patrol_test'),
      scenarios: allScenarios,
      declaredNamesByRelativePath: _loadDeclaredNames(
        projectPath,
        leafRelativePaths ??
            _discoverLeaves(projectPath, preferredTestDir: 'patrol_test'),
      ),
    );

    return BatchReport(
      projectName: projectName,
      projectPath: projectPath,
      generatedAt: DateTime.now(),
      targets: targets,
      leaves: leaves,
      scenarios: allScenarios,
      device: device,
      runMode: runMode,
    );
  }

  String _logFor(RunRecord record) {
    if (record.combinedLog.trim().isNotEmpty) return record.combinedLog;
    final buf = StringBuffer();
    if (record.stdoutLog.isNotEmpty) buf.writeln(record.stdoutLog);
    if (record.stderrLog.isNotEmpty) buf.writeln(record.stderrLog);
    if (record.logs.isNotEmpty) {
      for (final e in record.logs) {
        buf.writeln(e.exportText);
      }
    }
    return buf.toString();
  }

  String _targetLabel(RunRecord record) {
    final tf = record.targetFile;
    if (tf != null && tf.isNotEmpty) {
      return p.basenameWithoutExtension(tf);
    }
    return record.queueLabel ?? record.runId;
  }

  String? _relativeTarget(String projectPath, String? targetFile) {
    if (targetFile == null || targetFile.isEmpty) return null;
    final normalized = targetFile.replaceAll('\\', '/');
    final root = projectPath.replaceAll('\\', '/');
    if (p.isWithin(projectPath, targetFile) ||
        normalized.startsWith('$root/')) {
      return p.relative(targetFile, from: projectPath).replaceAll('\\', '/');
    }
    // Already relative?
    if (!p.isAbsolute(targetFile)) {
      return normalized;
    }
    return null;
  }

  List<LeafFileResult> _mapLeaves({
    required String projectPath,
    required List<String> leafRelativePaths,
    required List<ScenarioResult> scenarios,
    required Map<String, List<String>> declaredNamesByRelativePath,
    Map<String, List<ScenarioResult>> directByRel = const {},
    bool onlyRanLeaves = true,
  }) {
    final remaining = List<ScenarioResult>.from(scenarios);
    final results = <LeafFileResult>[];
    final usedDirect = <ScenarioResult>{};

    for (final rel in leafRelativePaths) {
      // Skip suite entrypoints from leaf inventory when path looks like suite/
      if (rel.contains('/suite/') || rel.startsWith('suite/')) {
        continue;
      }
      final declared = declaredNamesByRelativePath[rel] ?? const <String>[];
      final matched = <ScenarioResult>[];

      // Prefer direct targetFile → leaf mapping (Test All per-file runs)
      final direct = directByRel[rel];
      if (direct != null && direct.isNotEmpty) {
        matched.addAll(direct);
        usedDirect.addAll(direct);
        remaining.removeWhere((s) => direct.any((d) => identical(d, s) ||
            (d.name == s.name && d.status == s.status)));
      }

      // Exact / substring match on declared patrolTest names
      if (matched.isEmpty) {
        for (final dn in declared) {
          final nd = _normalize(dn);
          if (nd.isEmpty) continue;
          remaining.removeWhere((s) {
            final nc = _normalize(s.name);
            if (nc == nd || nc.contains(nd)) {
              matched.add(s);
              return true;
            }
            if (nd.length >= 20 && nd.contains(nc) && nc.length >= 12) {
              matched.add(s);
              return true;
            }
            return false;
          });
        }
      }

      // Strict basename token match (avoid weak single-token hits like "rate")
      if (matched.isEmpty && !onlyRanLeaves) {
        final base = p
            .basenameWithoutExtension(rel)
            .replaceAll('_test', '')
            .replaceAll('_', ' ');
        final tokens = _normalize(base)
            .split(' ')
            .where((t) => t.length > 3)
            .toSet();
        if (tokens.length >= 2) {
          remaining.removeWhere((s) {
            final nc = _normalize(s.name);
            final score = tokens.where((t) => nc.contains(t)).length;
            final need = tokens.length >= 4 ? 3 : 2;
            if (score >= need) {
              matched.add(s);
              return true;
            }
            return false;
          });
        }
      }

      // For this-batch-only reports, still list the leaf even if scenarios
      // could not be named — use direct scenarios or leave empty for status
      // from target rollup.
      if (onlyRanLeaves && matched.isEmpty && direct != null) {
        // already handled
      }

      // Skip pure "Not run" noise when onlyRanLeaves and nothing ran here
      if (onlyRanLeaves &&
          matched.isEmpty &&
          (direct == null || direct.isEmpty) &&
          !directByRel.containsKey(rel)) {
        continue;
      }

      results.add(
        LeafFileResult(
          relativePath: rel,
          area: _areaOf(rel),
          scenarios: matched,
          declaredNames: declared,
        ),
      );
    }

    // Orphan scenarios: attach under synthetic leaf if any remain
    remaining.removeWhere(
      (s) => usedDirect.any(
        (d) => d.name == s.name && d.status == s.status,
      ),
    );
    if (remaining.isNotEmpty) {
      results.add(
        LeafFileResult(
          relativePath: '(unmapped scenarios)',
          area: 'other',
          scenarios: List.of(remaining),
        ),
      );
    }

    results.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return results;
  }

  String _areaOf(String rel) {
    final parts = rel.replaceAll('\\', '/').split('/');
    // patrol_test/account/foo → account; integration_test/x → integration_test
    if (parts.length >= 2) {
      if (parts.first == 'patrol_test' || parts.first == 'integration_test') {
        return parts.length >= 3 ? parts[1] : parts.first;
      }
      return parts.first;
    }
    return 'root';
  }

  String _normalize(String s) {
    var t = s.toLowerCase();
    t = t.replaceAll(RegExp(r'\$\{[^}]+\}'), '');
    t = t.replaceAll(RegExp(r'\$\w+'), '');
    t = t.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<String> _discoverLeaves(
    String projectPath, {
    required String preferredTestDir,
  }) {
    final dirs = <String>[
      preferredTestDir,
      'patrol_test',
      'integration_test',
    ];
    final seen = <String>{};
    final out = <String>[];
    for (final dir in dirs) {
      final root = Directory(p.join(projectPath, dir));
      if (!root.existsSync()) continue;
      _walkTests(root, projectPath, out, seen);
      if (out.isNotEmpty) break;
    }
    out.sort();
    return out;
  }

  void _walkTests(
    Directory dir,
    String projectPath,
    List<String> out,
    Set<String> seen,
  ) {
    late final List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } catch (_) {
      return;
    }
    for (final e in entries) {
      final name = p.basename(e.path);
      if (e is Directory) {
        if (name.startsWith('.') ||
            name == 'build' ||
            name == '.dart_tool') {
          continue;
        }
        _walkTests(e, projectPath, out, seen);
      } else if (e is File && name.endsWith('_test.dart')) {
        final rel =
            p.relative(e.path, from: projectPath).replaceAll('\\', '/');
        if (seen.add(rel)) out.add(rel);
      }
    }
  }

  Map<String, List<String>> _loadDeclaredNames(
    String projectPath,
    List<String> leaves,
  ) {
    final map = <String, List<String>>{};
    for (final rel in leaves) {
      final file = File(p.join(projectPath, rel));
      if (!file.existsSync()) continue;
      try {
        final content = file.readAsStringSync();
        final cases = parseTestContent(content, parentFile: rel);
        map[rel] = cases
            .where((c) => c.testType == TestCaseType.patrolTest)
            .map((c) => c.testName)
            .toList();
      } catch (_) {
        map[rel] = const [];
      }
    }
    return map;
  }
}
