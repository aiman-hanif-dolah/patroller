import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/models.dart';
import 'app_paths.dart';
import 'settings_store.dart';

class HistoryStore {
  HistoryStore._();

  static final HistoryStore instance = HistoryStore._();

  Directory? _basePath;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final userDir = await patrolStudioUserDataDir();
    _basePath = Directory(p.join(userDir.path, 'history'));
    if (!_basePath!.existsSync()) {
      await _basePath!.create(recursive: true);
    }
    _initialized = true;
  }

  String _safeProjectName(String projectPath) {
    return projectPath.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  Future<Directory> _projectDir(String projectPath) async {
    await _ensureInitialized();
    final dir = Directory(p.join(_basePath!.path, _safeProjectName(projectPath)));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _runFile(String projectPath, String runId) async {
    final dir = await _projectDir(projectPath);
    return File(p.join(dir.path, '$runId.json'));
  }

  Future<void> save(RunRecord record, SettingsStore settingsStore) async {
    final file = await _runFile(record.projectPath, record.runId);
    final json = const JsonEncoder.withIndent('  ').convert(record.toJson());
    await file.writeAsString(json);
    await _enforceRetention(record.projectPath, settingsStore);
  }

  Future<RunRecord?> get(String runId, String projectPath) async {
    try {
      final file = await _runFile(projectPath, runId);
      if (!file.existsSync()) return null;
      final parsed = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return RunRecord.fromJson(parsed);
    } catch (_) {
      return null;
    }
  }

  Future<List<RunRecord>> getAll(String projectPath) async {
    try {
      final dir = await _projectDir(projectPath);
      final records = <RunRecord>[];
      await for (final entity in dir.list()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        try {
          final parsed =
              jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
          records.add(RunRecord.fromJson(parsed));
        } catch (_) {}
      }
      records.sort((a, b) => b.startTime.compareTo(a.startTime));
      return records;
    } catch (_) {
      return [];
    }
  }

  Future<void> delete(String runId, String projectPath) async {
    try {
      final file = await _runFile(projectPath, runId);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> clear(String projectPath) async {
    try {
      final dir = await _projectDir(projectPath);
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          await entity.delete();
        }
      }
    } catch (_) {}
  }

  Future<void> _enforceRetention(
    String projectPath,
    SettingsStore settingsStore,
  ) async {
    final settings = await settingsStore.getAsync();
    final maxRuns = settings.logRetentionCount;
    final records = await getAll(projectPath);
    if (records.length > maxRuns) {
      for (final record in records.skip(maxRuns)) {
        await delete(record.runId, projectPath);
      }
    }
  }
}