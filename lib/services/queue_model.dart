import 'package:path/path.dart' as p;

import '../models/models.dart';
import 'run_lifecycle.dart';

const String skipAfterFailure = 'skipped after failure';
const String skipByUserStop = 'skipped by user stop';

class QueueCounts {
  const QueueCounts({
    required this.passedCount,
    required this.failedCount,
    required this.cancelledCount,
    required this.skippedCount,
  });

  final int passedCount;
  final int failedCount;
  final int cancelledCount;
  final int skippedCount;
}

QueueCounts countQueueOutcomes(List<QueueRunOutcome> results) {
  return QueueCounts(
    passedCount: results.where((r) => r == QueueRunOutcome.passed).length,
    failedCount: results
        .where((r) => r == QueueRunOutcome.failed || r == QueueRunOutcome.error)
        .length,
    cancelledCount: results.where((r) => r == QueueRunOutcome.cancelled).length,
    skippedCount: results.where((r) => r == QueueRunOutcome.skipped).length,
  );
}

bool shouldContinueQueue(
  List<QueueRunOutcome> results,
  bool stopRequested,
  bool stopOnFirstFailure,
) {
  if (stopRequested) return false;
  if (stopOnFirstFailure &&
      results.any(
        (r) => r == QueueRunOutcome.failed || r == QueueRunOutcome.error,
      )) {
    return false;
  }
  return true;
}

String skipReasonForQueue(bool stopRequested) =>
    stopRequested ? skipByUserStop : skipAfterFailure;

QueueStatus queueFinalStatus(List<QueueRunOutcome> results, bool stopRequested) {
  if (stopRequested) return QueueStatus.stopped;
  final counts = countQueueOutcomes(results);
  return counts.failedCount > 0 ? QueueStatus.failed : QueueStatus.completed;
}

RunRecordStatus queueSummaryRecordStatus(
  List<QueueRunOutcome> results,
  bool stopRequested,
) {
  if (stopRequested) return RunRecordStatus.cancelled;
  final counts = countQueueOutcomes(results);
  return counts.failedCount > 0 ? RunRecordStatus.failed : RunRecordStatus.passed;
}

List<QueueChildSnapshot> buildQueueChildSnapshots(List<RunRecord> records) {
  return records
      .map(
        (record) => QueueChildSnapshot(
          runId: record.runId,
          targetFile: record.targetFile,
          status: record.status,
          queueIndex: record.queueIndex ?? 0,
        ),
      )
      .toList()
    ..sort((a, b) => a.queueIndex.compareTo(b.queueIndex));
}

String buildQueueSummaryDisplay({
  required String queueLabel,
  required List<String> files,
  required List<QueueRunOutcome> results,
}) {
  final counts = countQueueOutcomes(results);
  final notStarted = (files.length - results.length).clamp(0, files.length);
  final parts = <String>[
    queueLabel,
    '${files.length} file${files.length == 1 ? '' : 's'}',
    '${counts.passedCount} passed',
    '${counts.failedCount} failed',
    '${counts.cancelledCount} cancelled',
  ];
  if (counts.skippedCount > 0) {
    parts.add('${counts.skippedCount} skipped');
  }
  if (notStarted > 0) {
    parts.add('$notStarted not started');
  }
  return parts.join(' · ');
}

RunRecord buildSkippedRunRecord({
  required String queueId,
  required String queueLabel,
  required String projectPath,
  required String projectName,
  required String? deviceId,
  required String targetFile,
  required int queueIndex,
  required int queueTotal,
  required String statusReason,
  required String startedAt,
  required String endedAt,
  required String appVersion,
}) {
  return RunRecord(
    runId: '${queueId}_skip_$queueIndex',
    projectId: projectName,
    projectPath: projectPath,
    projectName: projectName,
    command: 'patrol',
    args: const [],
    fullCommandForDisplay:
        'skipped: ${p.basename(targetFile.replaceAll('\\', '/'))}',
    targetFile: targetFile,
    targetFiles: const [],
    runMode: RunMode.test,
    selectedDevice: deviceId,
    recordingId: null,
    startTime: startedAt,
    endTime: endedAt,
    durationMs: 0,
    exitCode: null,
    status: RunRecordStatus.skipped,
    statusReason: statusReason,
    stdoutLog: '',
    stderrLog: '',
    combinedLog: '',
    logs: const [],
    failureSummary: null,
    environmentSnapshot: '',
    appVersion: appVersion,
    queueId: queueId,
    queueLabel: queueLabel,
    queueIndex: queueIndex,
    queueTotal: queueTotal,
  );
}

RunRecord buildQueueSummaryRecord({
  required String queueId,
  required String queueLabel,
  required String projectPath,
  required String projectName,
  required String? deviceId,
  required List<String> files,
  required List<QueueRunOutcome> results,
  required bool stopRequested,
  required String startedAt,
  required String endedAt,
  required String appVersion,
  List<QueueChildSnapshot>? childSnapshots,
}) {
  final started = DateTime.tryParse(startedAt) ?? DateTime.now().toUtc();
  final ended = DateTime.tryParse(endedAt) ?? DateTime.now().toUtc();
  return RunRecord(
    runId: '${queueId}_summary',
    projectId: projectName,
    projectPath: projectPath,
    projectName: projectName,
    command: 'patrol',
    args: const [],
    fullCommandForDisplay: buildQueueSummaryDisplay(
      queueLabel: queueLabel,
      files: files,
      results: results,
    ),
    targetFile: null,
    targetFiles: files,
    runMode: RunMode.test,
    selectedDevice: deviceId,
    recordingId: null,
    startTime: startedAt,
    endTime: endedAt,
    durationMs: ended.difference(started).inMilliseconds.clamp(0, 1 << 31),
    exitCode: null,
    status: queueSummaryRecordStatus(results, stopRequested),
    statusReason: stopRequested ? cancelledByUser : null,
    stdoutLog: '',
    stderrLog: '',
    combinedLog: '',
    logs: const [],
    failureSummary: null,
    environmentSnapshot: '',
    appVersion: appVersion,
    queueId: queueId,
    queueLabel: queueLabel,
    queueTotal: files.length,
    isQueueSummary: true,
    queueChildSnapshots: childSnapshots ?? const [],
  );
}

QueueStatusUpdate buildQueueStatusUpdate({
  required String queueId,
  required QueueStatus status,
  required int currentIndex,
  required int total,
  required String? activeRunId,
  required List<QueueRunOutcome> results,
  required String startedAt,
  required String? endedAt,
}) {
  final counts = countQueueOutcomes(results);
  return QueueStatusUpdate(
    queueId: queueId,
    status: status,
    currentIndex: currentIndex,
    total: total,
    activeRunId: activeRunId,
    passedCount: counts.passedCount,
    failedCount: counts.failedCount,
    cancelledCount: counts.cancelledCount,
    skippedCount: counts.skippedCount,
    startedAt: startedAt,
    endedAt: endedAt,
  );
}

QueueRunOutcome runRecordOutcome(RunRecord record) {
  switch (record.status) {
    case RunRecordStatus.passed:
      return QueueRunOutcome.passed;
    case RunRecordStatus.cancelled:
      return QueueRunOutcome.cancelled;
    case RunRecordStatus.skipped:
      return QueueRunOutcome.skipped;
    case RunRecordStatus.error:
      return QueueRunOutcome.error;
    default:
      return QueueRunOutcome.failed;
  }
}