import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/runner_helpers.dart';
import '../models/models.dart';

class FailedLogSnapshot {
  const FailedLogSnapshot({
    required this.runId,
    required this.targetFile,
    required this.startTime,
    required this.status,
    required this.logs,
    required this.exportText,
  });

  final String runId;
  final String? targetFile;
  final String startTime;
  final RunRecordStatus status;
  final List<LogEvent> logs;
  final String exportText;
}

class FailedLogsState {
  const FailedLogsState({this.entries = const []});

  final List<FailedLogSnapshot> entries;

  FailedLogsState copyWith({List<FailedLogSnapshot>? entries}) {
    return FailedLogsState(entries: entries ?? this.entries);
  }
}

class FailedLogsNotifier extends StateNotifier<FailedLogsState> {
  FailedLogsNotifier() : super(const FailedLogsState());

  void captureFailure({
    required RunRecord record,
    required List<LogEvent> liveLogs,
  }) {
    if (!isFailedRunStatus(record.status)) return;

    final runLogs = liveLogs.where((log) => log.runId == record.runId).toList();
    final logs = runLogs.isNotEmpty ? runLogs : record.logs;
    final exportText = formatRunLogsForExport(
      logs: logs,
      combinedLog: record.combinedLog,
      stderrLog: record.stderrLog,
    );
    if (exportText.trim().isEmpty) return;

    final snapshot = FailedLogSnapshot(
      runId: record.runId,
      targetFile: record.targetFile,
      startTime: record.startTime,
      status: record.status,
      logs: List<LogEvent>.from(logs),
      exportText: exportText,
    );

    final withoutDuplicate =
        state.entries.where((entry) => entry.runId != record.runId).toList();
    state = FailedLogsState(entries: [snapshot, ...withoutDuplicate]);
  }

  void clear() => state = const FailedLogsState();
}

final failedLogsProvider =
    StateNotifierProvider<FailedLogsNotifier, FailedLogsState>(
  (ref) => FailedLogsNotifier(),
);