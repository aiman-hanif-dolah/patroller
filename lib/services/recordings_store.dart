import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/recording.dart';
import 'app_paths.dart';

class RecordingsStore {
  RecordingsStore._();

  static final RecordingsStore instance = RecordingsStore._();

  Directory get _basePath {
    final dir = Directory(p.join(patrolStudioUserDataDirSync().path, 'recordings'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Directory _projectDir(String projectPath) {
    final safeName = projectPath.split('').map((c) {
      if (RegExp(r'[a-zA-Z0-9_-]').hasMatch(c)) return c;
      return '_';
    }).join();
    final dir = Directory(p.join(_basePath.path, safeName));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  File _recordingPath(String projectPath, String recordingId) {
    return File(p.join(_projectDir(projectPath).path, '$recordingId.json'));
  }

  Recording save(RecordingDraft draft) {
    final now = DateTime.now().toUtc().toIso8601String();
    final name = draft.name.trim().isEmpty
        ? 'Recording ${DateTime.now().toLocal()}'
        : draft.name.trim();

    final recording = Recording(
      id: 'rec_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 6)}',
      name: name,
      projectPath: draft.projectPath,
      createdAt: now,
      updatedAt: now,
      deviceName: draft.deviceName,
      deviceType: draft.deviceType,
      environmentProfile: draft.environmentProfile,
      actionCount: draft.actions.length,
      durationMs: draft.durationMs,
      actions: draft.actions,
      logs: draft.logs,
      stateSnapshots: draft.stateSnapshots ?? const [],
      replayResults: const [],
      generatedTestFiles: const [],
    );

    _write(recording);
    return recording;
  }

  Recording importRecording(String projectPath, String content) {
    final source = _parseRecordingImport(content);
    _validateRecording(source);
    final now = DateTime.now().toUtc().toIso8601String();
    var recording = source;
    recording = Recording(
      id: 'rec_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 6)}',
      name: recording.name.isEmpty
          ? 'Imported recording ${DateTime.now().toLocal()}'
          : '${recording.name} (imported)',
      projectPath: projectPath,
      createdAt: now,
      updatedAt: now,
      deviceName: recording.deviceName,
      deviceType: recording.deviceType,
      environmentProfile: recording.environmentProfile,
      actionCount: recording.actions.length,
      durationMs: recording.durationMs,
      actions: recording.actions,
      logs: recording.logs,
      stateSnapshots: recording.stateSnapshots,
      replayResults: recording.replayResults,
      generatedTestFiles: recording.generatedTestFiles,
    );
    _write(recording);
    return recording;
  }

  Recording? get(String recordingId, String projectPath) {
    final file = _recordingPath(projectPath, recordingId);
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return _normalizeRecording(Recording.fromJson(json));
    } catch (_) {
      return null;
    }
  }

  List<Recording> getAll(String projectPath) {
    final dir = _projectDir(projectPath);
    final recordings = <Recording>[];
    if (!dir.existsSync()) return recordings;
    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final json =
            jsonDecode(entity.readAsStringSync()) as Map<String, dynamic>;
        recordings.add(_normalizeRecording(Recording.fromJson(json)));
      } catch (_) {}
    }
    recordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return recordings;
  }

  void delete(String recordingId, String projectPath) {
    final file = _recordingPath(projectPath, recordingId);
    if (file.existsSync()) file.deleteSync();
  }

  Recording rename(String recordingId, String projectPath, String name) {
    final recording = get(recordingId, projectPath);
    if (recording == null) throw Exception('Recording not found');
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw Exception('Recording name cannot be empty');
    final updated = Recording(
      id: recording.id,
      name: trimmed,
      projectPath: recording.projectPath,
      createdAt: recording.createdAt,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      deviceName: recording.deviceName,
      deviceType: recording.deviceType,
      environmentProfile: recording.environmentProfile,
      actionCount: recording.actionCount,
      durationMs: recording.durationMs,
      actions: recording.actions,
      logs: recording.logs,
      stateSnapshots: recording.stateSnapshots,
      replayResults: recording.replayResults,
      generatedTestFiles: recording.generatedTestFiles,
    );
    _write(updated);
    return updated;
  }

  Recording? appendStateSnapshots(
    String recordingId,
    String projectPath,
    List<RecordingStateSnapshot> snapshots,
  ) {
    if (snapshots.isEmpty) return get(recordingId, projectPath);
    final recording = get(recordingId, projectPath);
    if (recording == null) return null;
    var stateSnapshots = [...recording.stateSnapshots, ...snapshots];
    if (stateSnapshots.length > 40) {
      stateSnapshots = stateSnapshots.sublist(stateSnapshots.length - 40);
    }
    final updated = Recording(
      id: recording.id,
      name: recording.name,
      projectPath: recording.projectPath,
      createdAt: recording.createdAt,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      deviceName: recording.deviceName,
      deviceType: recording.deviceType,
      environmentProfile: recording.environmentProfile,
      actionCount: recording.actionCount,
      durationMs: recording.durationMs,
      actions: recording.actions,
      logs: recording.logs,
      stateSnapshots: stateSnapshots,
      replayResults: recording.replayResults,
      generatedTestFiles: recording.generatedTestFiles,
    );
    _write(updated);
    return updated;
  }

  Recording? appendReplayResult(
    String recordingId,
    String projectPath,
    RecordingReplayResult result,
  ) {
    final recording = get(recordingId, projectPath);
    if (recording == null) return null;
    final replayResults = [result, ...recording.replayResults].take(20).toList();
    final updated = Recording(
      id: recording.id,
      name: recording.name,
      projectPath: recording.projectPath,
      createdAt: recording.createdAt,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      deviceName: recording.deviceName,
      deviceType: recording.deviceType,
      environmentProfile: recording.environmentProfile,
      actionCount: recording.actionCount,
      durationMs: recording.durationMs,
      actions: recording.actions,
      logs: recording.logs,
      stateSnapshots: recording.stateSnapshots,
      replayResults: replayResults,
      generatedTestFiles: recording.generatedTestFiles,
    );
    _write(updated);
    return updated;
  }

  Recording? appendGeneratedTestFile(
    String recordingId,
    String projectPath,
    RecordingTestFile testFile,
  ) {
    final recording = get(recordingId, projectPath);
    if (recording == null) return null;
    final generated = [testFile, ...recording.generatedTestFiles].take(20).toList();
    final updated = recording.copyWith(
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      generatedTestFiles: generated,
    );
    _write(updated);
    return updated;
  }

  /// Replace the action list for a saved recording (Flow Editor).
  Recording? replaceActions(
    String recordingId,
    String projectPath,
    List<RecordingAction> actions,
  ) {
    final recording = get(recordingId, projectPath);
    if (recording == null) return null;
    final updated = recording.copyWith(
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      actions: List<RecordingAction>.from(actions),
      actionCount: actions.length,
    );
    _write(updated);
    return updated;
  }

  void _write(Recording recording) {
    final json = const JsonEncoder.withIndent('  ').convert(recording.toJson());
    _recordingPath(recording.projectPath, recording.id).writeAsStringSync(json);
  }

  Recording _parseRecordingImport(String content) {
    final parsed = jsonDecode(content);
    if (parsed is Map<String, dynamic> && parsed['json'] is String) {
      return Recording.fromJson(
        jsonDecode(parsed['json'] as String) as Map<String, dynamic>,
      );
    }
    if (parsed is Map<String, dynamic>) {
      return Recording.fromJson(parsed);
    }
    throw Exception('Recording JSON is invalid.');
  }

  Recording _normalizeRecording(Recording recording) {
    final actions = recording.actions.asMap().entries.map((entry) {
      final action = entry.value;
      if (action.id.trim().isEmpty) {
        return action.copyWith(id: 'act_imported_${entry.key + 1}');
      }
      return action;
    }).toList();
    return Recording(
      id: recording.id,
      name: recording.name,
      projectPath: recording.projectPath,
      createdAt: recording.createdAt,
      updatedAt: recording.updatedAt,
      deviceName: recording.deviceName,
      deviceType: recording.deviceType,
      environmentProfile: recording.environmentProfile,
      actionCount: recording.actionCount,
      durationMs: recording.durationMs,
      actions: actions,
      logs: recording.logs,
      stateSnapshots: recording.stateSnapshots,
      replayResults: recording.replayResults,
      generatedTestFiles: recording.generatedTestFiles,
    );
  }

  void _validateRecording(Recording recording) {
    const validProfiles = RecordingEnvironmentProfile.values;
    if (!validProfiles.contains(recording.environmentProfile)) {
      throw Exception('Recording JSON has an invalid environment profile.');
    }
    for (var i = 0; i < recording.actions.length; i++) {
      final type = recording.actions[i].type;
      if (!RecordingActionType.values.contains(type)) {
        throw Exception(
          'Recording JSON has an unsupported action type at index $i',
        );
      }
    }
  }
}