import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/log_classification.dart';
import '../domain/log_sanitizer.dart';
import '../models/models.dart';
import '../services/patrol_studio_facade.dart';
import 'facade_provider.dart';

class LogState {
  const LogState({
    this.logs = const [],
    this.activeLogRunId,
    this.logFilters = LogFilters.defaults,
    this.logSearch = '',
    this.autoScroll = true,
    this.logRetentionCount = 100,
    this.revision = 0,
  });

  final List<LogEvent> logs;
  final String? activeLogRunId;
  final LogFilters logFilters;
  final String logSearch;
  final bool autoScroll;
  final int logRetentionCount;
  final int revision;

  LogState copyWith({
    List<LogEvent>? logs,
    String? activeLogRunId,
    LogFilters? logFilters,
    String? logSearch,
    bool? autoScroll,
    int? logRetentionCount,
    int? revision,
    bool clearActiveLogRunId = false,
  }) {
    return LogState(
      logs: logs ?? this.logs,
      activeLogRunId: clearActiveLogRunId
          ? null
          : (activeLogRunId ?? this.activeLogRunId),
      logFilters: logFilters ?? this.logFilters,
      logSearch: logSearch ?? this.logSearch,
      autoScroll: autoScroll ?? this.autoScroll,
      logRetentionCount: logRetentionCount ?? this.logRetentionCount,
      revision: revision ?? this.revision,
    );
  }
}

class LogNotifier extends StateNotifier<LogState> {
  LogNotifier(this._ref) : super(const LogState()) {
    _subscribe();
  }

  final Ref _ref;

  PatrolStudioFacade get _facade => _ref.read(patrolStudioFacadeProvider);

  void _subscribe() {
    _facade.runner.onLogs().listen(addLogs);
  }

  void applySettings(AppSettings settings) {
    state = state.copyWith(
      logRetentionCount: settings.logRetentionCount.clamp(10, 1000),
      autoScroll: settings.autoScrollLogs,
      logs: _trim(state.logs, settings.logRetentionCount),
      revision: state.revision + 1,
    );
  }

  List<LogEvent> _trim(List<LogEvent> logs, int retention) {
    if (logs.length <= retention) return logs;
    return logs.sublist(logs.length - retention);
  }

  void setActiveLogRunId(String? runId) {
    state = state.copyWith(activeLogRunId: runId);
  }

  void addLogs(List<LogEvent> incoming) {
    if (incoming.isEmpty) return;

    var activeId = state.activeLogRunId;
    var accepted = activeId != null
        ? incoming.where((l) => l.runId == activeId).toList()
        : incoming;

    if (accepted.isEmpty && activeId != null) {
      final incomingRunId = incoming.first.runId;
      if (incomingRunId != activeId) {
        activeId = incomingRunId;
        accepted = incoming;
      }
    }

    if (accepted.isEmpty) return;

    final sanitized = accepted.map(_sanitizeIncomingLog).toList();
    final combined = [...state.logs, ...sanitized];
    state = state.copyWith(
      logs: _trim(combined, state.logRetentionCount),
      activeLogRunId: activeId,
      revision: state.revision + 1,
    );
  }

  Future<void> clearLogs() async {
    await _facade.runner.clearLogs();
    state = state.copyWith(logs: [], revision: state.revision + 1);
  }

  void setLogFilters(LogFilters filters) {
    state = state.copyWith(logFilters: filters);
  }

  void setLogFilterMode(LogFilterMode mode) {
    state = state.copyWith(
      logFilters: state.logFilters.copyWith(mode: mode),
    );
  }

  void setLogStreamFilter(LogStreamFilter stream) {
    state = state.copyWith(
      logFilters: state.logFilters.copyWith(stream: stream),
    );
  }

  void toggleLogFilterSource(LogFilterKey key) {
    final sources = Map<LogFilterKey, bool>.from(state.logFilters.sources);
    sources[key] = !(sources[key] ?? true);
    state = state.copyWith(
      logFilters: state.logFilters.copyWith(sources: sources),
    );
  }

  void resetLogUiState() {
    state = state.copyWith(
      logFilters: LogFilters.defaults,
      logSearch: '',
    );
  }

  void setLogSearch(String search) {
    state = state.copyWith(logSearch: search);
  }

  void setAutoScroll(bool value) {
    state = state.copyWith(autoScroll: value);
  }

  LogEvent _sanitizeIncomingLog(LogEvent log) {
    final sanitized = sanitizeLogText(log.text);
    if (sanitized == log.text) return log;
    return LogEvent(
      runId: log.runId,
      streamType: log.streamType,
      timestamp: log.timestamp,
      text: sanitized,
      lineNumber: log.lineNumber,
      source: log.source,
      rawText: log.rawText ?? log.text,
    );
  }

  void appendSystemLog(String runId, String text) {
    final log = LogEvent(
      runId: runId,
      streamType: LogStreamType.stderr,
      timestamp: DateTime.now().toUtc().toIso8601String(),
      text: text,
      lineNumber: state.logs.length + 1,
      source: LogSource.system,
    );
    final combined = [...state.logs, log];
    state = state.copyWith(
      logs: _trim(combined, state.logRetentionCount),
      revision: state.revision + 1,
    );
  }
}

final logProvider = StateNotifierProvider<LogNotifier, LogState>(
  (ref) => LogNotifier(ref),
);

final filteredLogsProvider = Provider<List<LogEvent>>((ref) {
  final logState = ref.watch(logProvider);
  final filtersActive = isLogFilterActive(logState.logFilters) ||
      logState.logSearch.trim().isNotEmpty;
  final base = filtersActive
      ? logState.logs
          .where(
            (log) => matchesLogFilters(
              log,
              logState.logFilters,
              logState.logSearch,
            ),
          )
          .toList()
      : logState.logs;
  return collapseRepeatedLogBlocks(base);
});