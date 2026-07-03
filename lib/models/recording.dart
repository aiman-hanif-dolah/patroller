import 'enums.dart';
import 'hierarchy.dart';

enum RecordingActionType {
  tap,
  longpress,
  swipe,
  text,
  key;

  String toJson() => name;

  static RecordingActionType fromJson(String value) =>
      RecordingActionType.values.firstWhere((e) => e.name == value, orElse: () => RecordingActionType.tap);
}

enum RecordingEnvironmentProfile {
  live,
  stub,
  mock;

  String toJson() => name;

  static RecordingEnvironmentProfile fromJson(String value) =>
      RecordingEnvironmentProfile.values.firstWhere((e) => e.name == value, orElse: () => RecordingEnvironmentProfile.live);
}

enum RecordingSource {
  embedded,
  external;
}

class RecordingAction {
  RecordingAction({
    required this.id,
    required this.type,
    required this.timestampMs,
    required this.delayMs,
    this.x,
    this.y,
    this.toX,
    this.toY,
    this.durationSec,
    this.text,
    this.key,
    this.targetLabel,
    this.targetType,
    this.targetFrame,
    this.screenFingerprint,
    this.stateSummary,
    this.stateChanged,
  });

  final String id;
  final RecordingActionType type;
  final int timestampMs;
  final int delayMs;
  final double? x;
  final double? y;
  final double? toX;
  final double? toY;
  final double? durationSec;
  final String? text;
  final String? key;
  final String? targetLabel;
  final String? targetType;
  final ElementFrame? targetFrame;
  final String? screenFingerprint;
  final String? stateSummary;
  final bool? stateChanged;

  RecordingAction copyWith({
    String? id,
    RecordingActionType? type,
    int? timestampMs,
    int? delayMs,
    double? x,
    double? y,
    double? toX,
    double? toY,
    double? durationSec,
    String? text,
    String? key,
    String? targetLabel,
    String? targetType,
    ElementFrame? targetFrame,
    String? screenFingerprint,
    String? stateSummary,
    bool? stateChanged,
  }) {
    return RecordingAction(
      id: id ?? this.id,
      type: type ?? this.type,
      timestampMs: timestampMs ?? this.timestampMs,
      delayMs: delayMs ?? this.delayMs,
      x: x ?? this.x,
      y: y ?? this.y,
      toX: toX ?? this.toX,
      toY: toY ?? this.toY,
      durationSec: durationSec ?? this.durationSec,
      text: text ?? this.text,
      key: key ?? this.key,
      targetLabel: targetLabel ?? this.targetLabel,
      targetType: targetType ?? this.targetType,
      targetFrame: targetFrame ?? this.targetFrame,
      screenFingerprint: screenFingerprint ?? this.screenFingerprint,
      stateSummary: stateSummary ?? this.stateSummary,
      stateChanged: stateChanged ?? this.stateChanged,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toJson(),
        'timestampMs': timestampMs,
        'delayMs': delayMs,
        if (x != null) 'x': x,
        if (y != null) 'y': y,
        if (toX != null) 'toX': toX,
        if (toY != null) 'toY': toY,
        if (durationSec != null) 'durationSec': durationSec,
        if (text != null) 'text': text,
        if (key != null) 'key': key,
        if (targetLabel != null) 'targetLabel': targetLabel,
        if (targetType != null) 'targetType': targetType,
        if (targetFrame != null) 'targetFrame': targetFrame!.toJson(),
        if (screenFingerprint != null) 'screenFingerprint': screenFingerprint,
        if (stateSummary != null) 'stateSummary': stateSummary,
        if (stateChanged != null) 'stateChanged': stateChanged,
      };

  factory RecordingAction.fromJson(Map<String, dynamic> json) {
    return RecordingAction(
      id: json['id'] as String? ?? '',
      type: RecordingActionType.fromJson(json['type'] as String? ?? 'tap'),
      timestampMs: json['timestampMs'] as int? ?? 0,
      delayMs: json['delayMs'] as int? ?? 0,
      x: (json['x'] as num?)?.toDouble(),
      y: (json['y'] as num?)?.toDouble(),
      toX: (json['toX'] as num?)?.toDouble(),
      toY: (json['toY'] as num?)?.toDouble(),
      durationSec: (json['durationSec'] as num?)?.toDouble(),
      text: json['text'] as String?,
      key: json['key'] as String?,
      targetLabel: json['targetLabel'] as String?,
      targetType: json['targetType'] as String?,
      targetFrame: json['targetFrame'] != null
          ? ElementFrame.fromJson(json['targetFrame'] as Map<String, dynamic>)
          : null,
      screenFingerprint: json['screenFingerprint'] as String?,
      stateSummary: json['stateSummary'] as String?,
      stateChanged: json['stateChanged'] as bool?,
    );
  }
}

class RecordingStateSnapshot {
  const RecordingStateSnapshot({
    required this.id,
    required this.timestampMs,
    required this.screenFingerprint,
    required this.visibleTexts,
    required this.primaryActions,
    this.selectedTab,
    this.title,
    required this.rawHierarchyPreview,
  });

  final String id;
  final int timestampMs;
  final String screenFingerprint;
  final List<String> visibleTexts;
  final List<String> primaryActions;
  final String? selectedTab;
  final String? title;
  final String rawHierarchyPreview;

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestampMs': timestampMs,
        'screenFingerprint': screenFingerprint,
        'visibleTexts': visibleTexts,
        'primaryActions': primaryActions,
        'selectedTab': selectedTab,
        'title': title,
        'rawHierarchyPreview': rawHierarchyPreview,
      };

  factory RecordingStateSnapshot.fromJson(Map<String, dynamic> json) {
    return RecordingStateSnapshot(
      id: json['id'] as String? ?? '',
      timestampMs: json['timestampMs'] as int? ?? 0,
      screenFingerprint: json['screenFingerprint'] as String? ?? '',
      visibleTexts: (json['visibleTexts'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      primaryActions: (json['primaryActions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      selectedTab: json['selectedTab'] as String?,
      title: json['title'] as String?,
      rawHierarchyPreview: json['rawHierarchyPreview'] as String? ?? '',
    );
  }
}

class RecordingLogSnapshot {
  const RecordingLogSnapshot({
    required this.timestamp,
    required this.runId,
    required this.streamType,
    required this.text,
    required this.lineNumber,
  });

  final String timestamp;
  final String runId;
  final LogStreamType streamType;
  final String text;
  final int lineNumber;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'runId': runId,
        'streamType': streamType.toJson(),
        'text': text,
        'lineNumber': lineNumber,
      };

  factory RecordingLogSnapshot.fromJson(Map<String, dynamic> json) {
    return RecordingLogSnapshot(
      timestamp: json['timestamp'] as String? ?? '',
      runId: json['runId'] as String? ?? '',
      streamType: LogStreamType.fromJson(json['streamType'] as String? ?? 'stdout'),
      text: json['text'] as String? ?? '',
      lineNumber: json['lineNumber'] as int? ?? 0,
    );
  }
}

class RecordingReplayResult {
  const RecordingReplayResult({
    required this.recordingId,
    this.source,
    required this.startedAt,
    required this.endedAt,
    required this.actionCount,
    required this.status,
    this.error,
    this.failedActionIndex,
    this.failedActionId,
    required this.logs,
  });

  final String recordingId;
  final String? source;
  final String startedAt;
  final String endedAt;
  final int actionCount;
  final String status;
  final String? error;
  final int? failedActionIndex;
  final String? failedActionId;
  final List<RecordingLogSnapshot> logs;

  Map<String, dynamic> toJson() => {
        'recordingId': recordingId,
        if (source != null) 'source': source,
        'startedAt': startedAt,
        'endedAt': endedAt,
        'actionCount': actionCount,
        'status': status,
        'error': error,
        if (failedActionIndex != null) 'failedActionIndex': failedActionIndex,
        if (failedActionId != null) 'failedActionId': failedActionId,
        'logs': logs.map((l) => l.toJson()).toList(),
      };

  factory RecordingReplayResult.fromJson(Map<String, dynamic> json) {
    return RecordingReplayResult(
      recordingId: json['recordingId'] as String? ?? '',
      source: json['source'] as String?,
      startedAt: json['startedAt'] as String? ?? '',
      endedAt: json['endedAt'] as String? ?? '',
      actionCount: json['actionCount'] as int? ?? 0,
      status: json['status'] as String? ?? 'failed',
      error: json['error'] as String?,
      failedActionIndex: json['failedActionIndex'] as int?,
      failedActionId: json['failedActionId'] as String?,
      logs: (json['logs'] as List<dynamic>?)
              ?.map((e) => RecordingLogSnapshot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class RecordingTestFile {
  const RecordingTestFile({
    required this.recordingId,
    required this.filePath,
    required this.relativePath,
    required this.createdAt,
  });

  final String recordingId;
  final String filePath;
  final String relativePath;
  final String createdAt;

  Map<String, dynamic> toJson() => {
        'recordingId': recordingId,
        'filePath': filePath,
        'relativePath': relativePath,
        'createdAt': createdAt,
      };

  factory RecordingTestFile.fromJson(Map<String, dynamic> json) {
    return RecordingTestFile(
      recordingId: json['recordingId'] as String? ?? '',
      filePath: json['filePath'] as String? ?? '',
      relativePath: json['relativePath'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class Recording {
  Recording({
    required this.id,
    required this.name,
    required this.projectPath,
    required this.createdAt,
    required this.updatedAt,
    this.deviceName,
    this.deviceType,
    required this.environmentProfile,
    required this.actionCount,
    required this.durationMs,
    required this.actions,
    required this.logs,
    this.stateSnapshots = const [],
    this.replayResults = const [],
    this.generatedTestFiles = const [],
  });

  final String id;
  final String name;
  final String projectPath;
  final String createdAt;
  final String updatedAt;
  final String? deviceName;
  final DeviceType? deviceType;
  final RecordingEnvironmentProfile environmentProfile;
  final int actionCount;
  final int durationMs;
  final List<RecordingAction> actions;
  final List<RecordingLogSnapshot> logs;
  final List<RecordingStateSnapshot> stateSnapshots;
  final List<RecordingReplayResult> replayResults;
  final List<RecordingTestFile> generatedTestFiles;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'projectPath': projectPath,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deviceName': deviceName,
        'deviceType': deviceType?.toJson(),
        'environmentProfile': environmentProfile.toJson(),
        'actionCount': actionCount,
        'durationMs': durationMs,
        'actions': actions.map((a) => a.toJson()).toList(),
        'logs': logs.map((l) => l.toJson()).toList(),
        'stateSnapshots': stateSnapshots.map((s) => s.toJson()).toList(),
        'replayResults': replayResults.map((r) => r.toJson()).toList(),
        'generatedTestFiles': generatedTestFiles.map((f) => f.toJson()).toList(),
      };

  factory Recording.fromJson(Map<String, dynamic> json) {
    return Recording(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      projectPath: json['projectPath'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      deviceName: json['deviceName'] as String?,
      deviceType: json['deviceType'] != null
          ? DeviceType.fromJson(json['deviceType'] as String)
          : null,
      environmentProfile: RecordingEnvironmentProfile.fromJson(
        json['environmentProfile'] as String? ?? 'live',
      ),
      actionCount: json['actionCount'] as int? ?? 0,
      durationMs: json['durationMs'] as int? ?? 0,
      actions: (json['actions'] as List<dynamic>?)
              ?.map((e) => RecordingAction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      logs: (json['logs'] as List<dynamic>?)
              ?.map((e) => RecordingLogSnapshot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      stateSnapshots: (json['stateSnapshots'] as List<dynamic>?)
              ?.map((e) => RecordingStateSnapshot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      replayResults: (json['replayResults'] as List<dynamic>?)
              ?.map((e) => RecordingReplayResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      generatedTestFiles: (json['generatedTestFiles'] as List<dynamic>?)
              ?.map((e) => RecordingTestFile.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class ExternalRecordingActionPayload {
  const ExternalRecordingActionPayload({
    required this.type,
    this.x,
    this.y,
    this.toX,
    this.toY,
    this.durationSec,
    this.text,
    this.key,
  });

  final RecordingActionType type;
  final double? x;
  final double? y;
  final double? toX;
  final double? toY;
  final double? durationSec;
  final String? text;
  final String? key;
}

class RecordingDraft {
  const RecordingDraft({
    required this.name,
    required this.projectPath,
    this.deviceName,
    this.deviceType,
    required this.environmentProfile,
    required this.durationMs,
    required this.actions,
    required this.logs,
    this.stateSnapshots,
  });

  final String name;
  final String projectPath;
  final String? deviceName;
  final DeviceType? deviceType;
  final RecordingEnvironmentProfile environmentProfile;
  final int durationMs;
  final List<RecordingAction> actions;
  final List<RecordingLogSnapshot> logs;
  final List<RecordingStateSnapshot>? stateSnapshots;
}

class RecordingExport {
  const RecordingExport({
    required this.recordingId,
    required this.json,
    required this.flow,
    required this.logs,
    required this.replayLogs,
    required this.patrolTest,
  });

  final String recordingId;
  final String json;
  final String flow;
  final String logs;
  final String replayLogs;
  final String patrolTest;
}