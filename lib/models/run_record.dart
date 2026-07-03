import 'enums.dart';

class RunConfig {
  const RunConfig({
    required this.projectPath,
    required this.runMode,
    this.targetFile,
    this.targetFiles,
    this.excludedFiles,
    this.deviceId,
    this.extraArgs,
    this.recordingId,
    this.queueId,
    this.queueLabel,
    this.queueIndex,
    this.queueTotal,
    this.testNamePattern,
  });

  final String projectPath;
  final RunMode runMode;
  final String? targetFile;
  final List<String>? targetFiles;
  final List<String>? excludedFiles;
  final String? deviceId;
  final List<String>? extraArgs;
  final String? recordingId;
  final String? queueId;
  final String? queueLabel;
  final int? queueIndex;
  final int? queueTotal;
  final String? testNamePattern;

  Map<String, dynamic> toJson() => {
        'projectPath': projectPath,
        'runMode': runMode.toJson(),
        if (targetFile != null) 'targetFile': targetFile,
        if (targetFiles != null) 'targetFiles': targetFiles,
        if (excludedFiles != null) 'excludedFiles': excludedFiles,
        if (deviceId != null) 'deviceId': deviceId,
        if (extraArgs != null) 'extraArgs': extraArgs,
        if (recordingId != null) 'recordingId': recordingId,
        if (queueId != null) 'queueId': queueId,
        if (queueLabel != null) 'queueLabel': queueLabel,
        if (queueIndex != null) 'queueIndex': queueIndex,
        if (queueTotal != null) 'queueTotal': queueTotal,
        if (testNamePattern != null) 'testNamePattern': testNamePattern,
      };

  factory RunConfig.fromJson(Map<String, dynamic> json) => RunConfig(
        projectPath: json['projectPath'] as String? ?? '',
        runMode: RunMode.fromJson(json['runMode'] as String? ?? 'test'),
        targetFile: json['targetFile'] as String?,
        targetFiles: (json['targetFiles'] as List<dynamic>?)?.cast<String>(),
        excludedFiles: (json['excludedFiles'] as List<dynamic>?)?.cast<String>(),
        deviceId: json['deviceId'] as String?,
        extraArgs: (json['extraArgs'] as List<dynamic>?)?.cast<String>(),
        recordingId: json['recordingId'] as String?,
        queueId: json['queueId'] as String?,
        queueLabel: json['queueLabel'] as String?,
        queueIndex: json['queueIndex'] as int?,
        queueTotal: json['queueTotal'] as int?,
        testNamePattern: json['testNamePattern'] as String?,
      );
}

class LogEvent {
  const LogEvent({
    required this.runId,
    required this.streamType,
    required this.timestamp,
    required this.text,
    required this.lineNumber,
    required this.source,
  });

  final String runId;
  final LogStreamType streamType;
  final String timestamp;
  final String text;
  final int lineNumber;
  final LogSource source;

  Map<String, dynamic> toJson() => {
        'runId': runId,
        'streamType': streamType.toJson(),
        'timestamp': timestamp,
        'text': text,
        'lineNumber': lineNumber,
        'source': source.toJson(),
      };

  factory LogEvent.fromJson(Map<String, dynamic> json) => LogEvent(
        runId: json['runId'] as String? ?? '',
        streamType: LogStreamType.fromJson(json['streamType'] as String? ?? 'stdout'),
        timestamp: json['timestamp'] as String? ?? '',
        text: json['text'] as String? ?? '',
        lineNumber: json['lineNumber'] as int? ?? 0,
        source: LogSource.fromJson(json['source'] as String? ?? 'Unknown'),
      );
}

class FailureSummary {
  const FailureSummary({
    required this.failureType,
    required this.logExcerpt,
    required this.likelyCause,
    required this.suggestedAction,
    required this.confidence,
  });

  final String failureType;
  final String logExcerpt;
  final String likelyCause;
  final String suggestedAction;
  final Confidence confidence;

  Map<String, dynamic> toJson() => {
        'failureType': failureType,
        'logExcerpt': logExcerpt,
        'likelyCause': likelyCause,
        'suggestedAction': suggestedAction,
        'confidence': confidence.toJson(),
      };

  factory FailureSummary.fromJson(Map<String, dynamic> json) => FailureSummary(
        failureType: json['failureType'] as String? ?? '',
        logExcerpt: json['logExcerpt'] as String? ?? '',
        likelyCause: json['likelyCause'] as String? ?? '',
        suggestedAction: json['suggestedAction'] as String? ?? '',
        confidence: Confidence.fromJson(json['confidence'] as String? ?? 'low'),
      );
}

class QueueChildSnapshot {
  const QueueChildSnapshot({
    required this.runId,
    this.targetFile,
    required this.status,
    required this.queueIndex,
  });

  final String runId;
  final String? targetFile;
  final RunRecordStatus status;
  final int queueIndex;

  Map<String, dynamic> toJson() => {
        'runId': runId,
        'targetFile': targetFile,
        'status': status.toJson(),
        'queueIndex': queueIndex,
      };

  factory QueueChildSnapshot.fromJson(Map<String, dynamic> json) => QueueChildSnapshot(
        runId: json['runId'] as String? ?? '',
        targetFile: json['targetFile'] as String?,
        status: RunRecordStatus.fromJson(json['status'] as String? ?? 'error'),
        queueIndex: json['queueIndex'] as int? ?? 0,
      );
}

class RunRecord {
  RunRecord({
    required this.runId,
    required this.projectId,
    required this.projectPath,
    required this.projectName,
    required this.command,
    required this.args,
    required this.fullCommandForDisplay,
    this.targetFile,
    required this.targetFiles,
    required this.runMode,
    this.selectedDevice,
    this.recordingId,
    required this.startTime,
    this.endTime,
    this.durationMs,
    this.exitCode,
    required this.status,
    this.lifecycle,
    this.statusReason,
    this.stopRequestedAt,
    this.endedAt,
    String stdoutLog = '',
    String stderrLog = '',
    String combinedLog = '',
    List<LogEvent>? logs,
    this.failureSummary,
    required this.environmentSnapshot,
    required this.appVersion,
    this.queueId,
    this.queueLabel,
    this.queueIndex,
    this.queueTotal,
    this.isQueueSummary,
    this.queueChildSnapshots,
    this.testNamePattern,
  })  : stdoutLog = stdoutLog,
        stderrLog = stderrLog,
        combinedLog = combinedLog,
        logs = logs ?? <LogEvent>[];

  final String runId;
  final String projectId;
  final String projectPath;
  final String projectName;
  final String command;
  final List<String> args;
  final String fullCommandForDisplay;
  final String? targetFile;
  final List<String> targetFiles;
  final RunMode runMode;
  final String? selectedDevice;
  final String? recordingId;
  final String startTime;
  String? endTime;
  int? durationMs;
  int? exitCode;
  RunRecordStatus status;
  RunLifecycle? lifecycle;
  String? statusReason;
  String? stopRequestedAt;
  String? endedAt;
  String stdoutLog;
  String stderrLog;
  String combinedLog;
  final List<LogEvent> logs;
  FailureSummary? failureSummary;
  final String environmentSnapshot;
  final String appVersion;
  final String? queueId;
  final String? queueLabel;
  final int? queueIndex;
  final int? queueTotal;
  final bool? isQueueSummary;
  final List<QueueChildSnapshot>? queueChildSnapshots;
  final String? testNamePattern;

  Map<String, dynamic> toJson() => {
        'runId': runId,
        'projectId': projectId,
        'projectPath': projectPath,
        'projectName': projectName,
        'command': command,
        'args': args,
        'fullCommandForDisplay': fullCommandForDisplay,
        'targetFile': targetFile,
        'targetFiles': targetFiles,
        'runMode': runMode.toJson(),
        'selectedDevice': selectedDevice,
        'recordingId': recordingId,
        'startTime': startTime,
        'endTime': endTime,
        'durationMs': durationMs,
        'exitCode': exitCode,
        'status': status.toJson(),
        if (lifecycle != null) 'lifecycle': lifecycle!.toJson(),
        'statusReason': statusReason,
        'stopRequestedAt': stopRequestedAt,
        'endedAt': endedAt,
        'stdoutLog': stdoutLog,
        'stderrLog': stderrLog,
        'combinedLog': combinedLog,
        'logs': logs.map((l) => l.toJson()).toList(),
        if (failureSummary != null) 'failureSummary': failureSummary!.toJson(),
        'environmentSnapshot': environmentSnapshot,
        'appVersion': appVersion,
        if (queueId != null) 'queueId': queueId,
        if (queueLabel != null) 'queueLabel': queueLabel,
        if (queueIndex != null) 'queueIndex': queueIndex,
        if (queueTotal != null) 'queueTotal': queueTotal,
        if (isQueueSummary != null) 'isQueueSummary': isQueueSummary,
        if (queueChildSnapshots != null)
          'queueChildSnapshots': queueChildSnapshots!.map((s) => s.toJson()).toList(),
        if (testNamePattern != null) 'testNamePattern': testNamePattern,
      };

  factory RunRecord.fromJson(Map<String, dynamic> json) => RunRecord(
        runId: json['runId'] as String? ?? '',
        projectId: json['projectId'] as String? ?? '',
        projectPath: json['projectPath'] as String? ?? '',
        projectName: json['projectName'] as String? ?? '',
        command: json['command'] as String? ?? '',
        args: (json['args'] as List<dynamic>? ?? []).cast<String>(),
        fullCommandForDisplay: json['fullCommandForDisplay'] as String? ?? '',
        targetFile: json['targetFile'] as String?,
        targetFiles: (json['targetFiles'] as List<dynamic>? ?? []).cast<String>(),
        runMode: RunMode.fromJson(json['runMode'] as String? ?? 'test'),
        selectedDevice: json['selectedDevice'] as String?,
        recordingId: json['recordingId'] as String?,
        startTime: json['startTime'] as String? ?? '',
        endTime: json['endTime'] as String?,
        durationMs: json['durationMs'] as int?,
        exitCode: json['exitCode'] as int?,
        status: RunRecordStatus.fromJson(json['status'] as String? ?? 'error'),
        lifecycle: json['lifecycle'] != null
            ? RunLifecycle.fromJson(json['lifecycle'] as String)
            : null,
        statusReason: json['statusReason'] as String?,
        stopRequestedAt: json['stopRequestedAt'] as String?,
        endedAt: json['endedAt'] as String?,
        stdoutLog: json['stdoutLog'] as String? ?? '',
        stderrLog: json['stderrLog'] as String? ?? '',
        combinedLog: json['combinedLog'] as String? ?? '',
        logs: (json['logs'] as List<dynamic>? ?? [])
            .map((e) => LogEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        failureSummary: json['failureSummary'] != null
            ? FailureSummary.fromJson(json['failureSummary'] as Map<String, dynamic>)
            : null,
        environmentSnapshot: json['environmentSnapshot'] as String? ?? '',
        appVersion: json['appVersion'] as String? ?? '1.0.0',
        queueId: json['queueId'] as String?,
        queueLabel: json['queueLabel'] as String?,
        queueIndex: json['queueIndex'] as int?,
        queueTotal: json['queueTotal'] as int?,
        isQueueSummary: json['isQueueSummary'] as bool?,
        queueChildSnapshots: (json['queueChildSnapshots'] as List<dynamic>?)
            ?.map((e) => QueueChildSnapshot.fromJson(e as Map<String, dynamic>))
            .toList(),
        testNamePattern: json['testNamePattern'] as String?,
      );
}

class RunStatusUpdate {
  const RunStatusUpdate({
    required this.runId,
    this.recordingId,
    required this.status,
    this.lifecycle,
    this.statusReason,
    this.stopRequestedAt,
    this.endedAt,
    this.exitCode,
    this.durationMs,
    this.endTime,
  });

  final String runId;
  final String? recordingId;
  final RunRecordStatus status;
  final RunLifecycle? lifecycle;
  final String? statusReason;
  final String? stopRequestedAt;
  final String? endedAt;
  final int? exitCode;
  final int? durationMs;
  final String? endTime;

  Map<String, dynamic> toJson() => {
        'runId': runId,
        'recordingId': recordingId,
        'status': status.toJson(),
        if (lifecycle != null) 'lifecycle': lifecycle!.toJson(),
        'statusReason': statusReason,
        'stopRequestedAt': stopRequestedAt,
        'endedAt': endedAt,
        'exitCode': exitCode,
        'durationMs': durationMs,
        'endTime': endTime,
      };
}

class StopResult {
  const StopResult({
    required this.runId,
    required this.outcome,
    required this.lifecycle,
    this.statusReason,
    this.error,
  });

  final String runId;
  final StopOutcome outcome;
  final RunLifecycle lifecycle;
  final String? statusReason;
  final String? error;
}

class StopAllFailure {
  const StopAllFailure({required this.runId, required this.error});

  final String runId;
  final String error;
}

class StopAllResult {
  const StopAllResult({required this.stoppedRunIds, required this.failures});

  final List<String> stoppedRunIds;
  final List<StopAllFailure> failures;
}

class ActiveSessionState {
  const ActiveSessionState({required this.runIds, required this.records});

  final List<String> runIds;
  final List<RunRecord> records;
}

class QueueStatusUpdate {
  const QueueStatusUpdate({
    required this.queueId,
    required this.status,
    required this.currentIndex,
    required this.total,
    this.activeRunId,
    required this.passedCount,
    required this.failedCount,
    required this.cancelledCount,
    required this.skippedCount,
    required this.startedAt,
    this.endedAt,
  });

  final String queueId;
  final QueueStatus status;
  final int currentIndex;
  final int total;
  final String? activeRunId;
  final int passedCount;
  final int failedCount;
  final int cancelledCount;
  final int skippedCount;
  final String startedAt;
  final String? endedAt;

  Map<String, dynamic> toJson() => {
        'queueId': queueId,
        'status': status.toJson(),
        'currentIndex': currentIndex,
        'total': total,
        'activeRunId': activeRunId,
        'passedCount': passedCount,
        'failedCount': failedCount,
        'cancelledCount': cancelledCount,
        'skippedCount': skippedCount,
        'startedAt': startedAt,
        'endedAt': endedAt,
      };
}

class StartQueueRequest {
  const StartQueueRequest({
    required this.files,
    required this.projectPath,
    this.deviceId,
    this.queueLabel,
  });

  final List<String> files;
  final String projectPath;
  final String? deviceId;
  final String? queueLabel;
}

class StartQueueResponse {
  const StartQueueResponse({required this.queueId});

  final String queueId;
}