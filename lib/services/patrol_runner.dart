import 'dart:async' show Completer, StreamController, unawaited;
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'cli_env.dart';
import 'command_builder.dart';
import 'history_store.dart';
import 'process_registry.dart';
import 'run_lifecycle.dart';
import 'settings_store.dart';

const String appVersion = '1.0.0';
const int logFlushIntervalMs = 400;
const int maxLogsPerFlush = 120;
const int maxRecordLogLines = 5000;

class StartRunOptions {
  const StartRunOptions({this.clearLogs = true});

  final bool clearLogs;
}

class StopRunOptions {
  const StopRunOptions({this.force = false, this.statusReason});

  final bool force;
  final String? statusReason;
}

class _ActiveRunContext {
  _ActiveRunContext({
    required this.record,
    required this.settingsStore,
    this.onComplete,
  });

  RunRecord record;
  final SettingsStore settingsStore;
  bool userStopRequested = false;
  bool forceStop = false;
  String? stopStatusReason;
  bool terminalEmitted = false;
  void Function(RunRecord record)? onComplete;
}

class PatrolRunner {
  PatrolRunner({
    required SettingsStore settingsStore,
    required HistoryStore historyStore,
    ProcessRegistry? registry,
  })  : _settingsStore = settingsStore,
        _historyStore = historyStore,
        _registry = registry ?? processRegistry;

  final SettingsStore _settingsStore;
  final HistoryStore _historyStore;
  final ProcessRegistry _registry;
  final Map<String, _ActiveRunContext> _activeRuns = {};
  final List<LogEvent> _pendingLogs = [];
  bool _logFlushScheduled = false;
  String? _activeLogRunId;

  final _logController = StreamController<List<LogEvent>>.broadcast();
  final _singleLogController = StreamController<LogEvent>.broadcast();
  final _statusController = StreamController<RunStatusUpdate>.broadcast();

  Stream<List<LogEvent>> get logBatches => _logController.stream;
  Stream<LogEvent> get logEvents => _singleLogController.stream;
  Stream<RunStatusUpdate> get statusUpdates => _statusController.stream;

  void dispose() {
    _logController.close();
    _singleLogController.close();
    _statusController.close();
  }

  String _generateRunId() {
    final uuid = const Uuid().v4().substring(0, 6);
    return 'run_${DateTime.now().millisecondsSinceEpoch}_$uuid';
  }

  (String cmd, List<String> args, String display) _buildCommand(RunConfig config) {
    final settings = _settingsStore.get();
    final built = buildPatrolCommand(
      PatrolCommandInput(
        config: config,
        patrolExecutable: resolveExecutable(
          'patrol',
          configuredPath: settings.patrolPath,
        ),
        extraPatrolArgs: settings.extraPatrolArgs,
      ),
    );
    return (built.cmd, built.args, built.display);
  }

  bool _containsIgnoreAsciiCase(String haystack, String needle) {
    if (needle.isEmpty) return true;
    return haystack.toLowerCase().contains(needle.toLowerCase());
  }

  LogSource _detectLogSource(String line) {
    if (_containsIgnoreAsciiCase(line, 'patrol') ||
        _containsIgnoreAsciiCase(line, 'integrationtest')) {
      return LogSource.patrol;
    }
    if (_containsIgnoreAsciiCase(line, 'flutter') ||
        _containsIgnoreAsciiCase(line, 'dart')) {
      return LogSource.flutter;
    }
    if (_containsIgnoreAsciiCase(line, 'xcode') ||
        _containsIgnoreAsciiCase(line, 'xcodebuild')) {
      return LogSource.xcode;
    }
    if (_containsIgnoreAsciiCase(line, 'simulator') ||
        _containsIgnoreAsciiCase(line, 'iphone') ||
        _containsIgnoreAsciiCase(line, 'device')) {
      return LogSource.device;
    }
    if (_containsIgnoreAsciiCase(line, 'error') ||
        _containsIgnoreAsciiCase(line, 'fail') ||
        _containsIgnoreAsciiCase(line, 'trace')) {
      return LogSource.system;
    }
    return LogSource.unknown;
  }

  String _extractExcerpt(String log, String keyword, {int contextLines = 3}) {
    final lines = const LineSplitter().convert(log);
    final idx = lines.indexWhere(
      (line) => line.toLowerCase().contains(keyword.toLowerCase()),
    );
    if (idx == -1) {
      return log.length > 500 ? log.substring(0, 500) : log;
    }
    final start = (idx - contextLines).clamp(0, lines.length);
    final end = (idx + contextLines + 1).clamp(0, lines.length);
    return lines.sublist(start, end).join('\n');
  }

  FailureSummary? _detectFailureSummary(String combinedLog, String stderrLog) {
    final log = '$combinedLog\n$stderrLog';
    final lower = log.toLowerCase();

    if (lower.contains('patrol: command not found') ||
        lower.contains('patrol: not found') ||
        (lower.contains('enoent') && lower.contains('patrol'))) {
      return FailureSummary(
        failureType: 'Patrol CLI missing',
        logExcerpt: _extractExcerpt(log, 'patrol'),
        likelyCause: 'Patrol CLI is not installed or not in PATH.',
        suggestedAction: 'Install Patrol CLI: dart pub global activate patrol_cli',
        confidence: Confidence.high,
      );
    }

    if (lower.contains('flutter: command not found')) {
      return FailureSummary(
        failureType: 'Flutter CLI missing',
        logExcerpt: _extractExcerpt(log, 'flutter'),
        likelyCause: 'Flutter is not installed or not in PATH.',
        suggestedAction: 'Install Flutter and ensure flutter is in PATH.',
        confidence: Confidence.high,
      );
    }

    if (lower.contains('build failed')) {
      return FailureSummary(
        failureType: 'Build failed',
        logExcerpt: _extractExcerpt(log, 'build failed'),
        likelyCause: 'The Flutter build failed. Check build logs for details.',
        suggestedAction:
            'Run flutter build ios or flutter build apk manually to see detailed errors.',
        confidence: Confidence.medium,
      );
    }

    if (lower.contains('test timed out') || lower.contains('timeout')) {
      return FailureSummary(
        failureType: 'Test timeout',
        logExcerpt: _extractExcerpt(log, 'timeout'),
        likelyCause: 'The test exceeded the timeout duration.',
        suggestedAction:
            'Check for infinite loops, slow animations, or increase timeout.',
        confidence: Confidence.medium,
      );
    }

    if (lower.contains('no such file or directory') && lower.contains('_test.dart')) {
      return FailureSummary(
        failureType: 'Test file not found',
        logExcerpt: _extractExcerpt(log, '_test.dart'),
        likelyCause: 'The specified test file does not exist at the expected path.',
        suggestedAction: 'Verify the test file path and test directory configuration.',
        confidence: Confidence.high,
      );
    }

    return null;
  }

  bool _shouldDeliverLog(String runId) =>
      _activeLogRunId == null || _activeLogRunId == runId;

  void _flushPendingLogs() {
    _logFlushScheduled = false;
    if (_pendingLogs.isEmpty) return;

    final batch = _pendingLogs.length > maxLogsPerFlush
        ? _pendingLogs.sublist(0, maxLogsPerFlush)
        : List<LogEvent>.from(_pendingLogs);

    if (_pendingLogs.length > maxLogsPerFlush) {
      _pendingLogs.removeRange(0, maxLogsPerFlush);
    } else {
      _pendingLogs.clear();
    }

    _logController.add(batch);
    for (final event in batch) {
      _singleLogController.add(event);
    }

    if (_pendingLogs.isNotEmpty) {
      _scheduleLogFlush();
    }
  }

  void _scheduleLogFlush() {
    if (_logFlushScheduled || _pendingLogs.isEmpty) return;
    _logFlushScheduled = true;
    Future<void>.delayed(
      const Duration(milliseconds: logFlushIntervalMs),
      _flushPendingLogs,
    );
  }

  void _queueLog(LogEvent event) {
    if (!_shouldDeliverLog(event.runId)) return;
    _pendingLogs.add(event);
    _scheduleLogFlush();
  }

  void _sendStatusUpdate(RunRecord record) {
    _statusController.add(
      RunStatusUpdate(
        runId: record.runId,
        recordingId: record.recordingId,
        status: record.status,
        lifecycle: record.lifecycle,
        statusReason: record.statusReason,
        stopRequestedAt: record.stopRequestedAt,
        endedAt: record.endedAt ?? record.endTime,
        exitCode: record.exitCode,
        durationMs: record.durationMs,
        endTime: record.endTime,
      ),
    );
  }

  LogEvent _appendRecordLogLine(
    RunRecord record,
    LogStreamType streamType,
    String line,
    int lineNumber,
    LogSource source,
  ) {
    final event = LogEvent(
      runId: record.runId,
      streamType: streamType,
      timestamp: DateTime.now().toUtc().toIso8601String(),
      text: line,
      lineNumber: lineNumber,
      source: source,
    );

    if (record.logs.length >= maxRecordLogLines) {
      record.logs.removeAt(0);
    }
    record.logs.add(event);

    final textWithNewline = '$line\n';
    switch (streamType) {
      case LogStreamType.stdout:
        record.stdoutLog += textWithNewline;
      case LogStreamType.stderr:
        record.stderrLog += textWithNewline;
    }
    record.combinedLog += textWithNewline;
    return event;
  }

  void _appendSystemLog(RunRecord record, String text) {
    final lineNumber = record.logs.length + 1;
    final event = _appendRecordLogLine(
      record,
      LogStreamType.stderr,
      text,
      lineNumber,
      LogSource.system,
    );
    _queueLog(event);
  }

  RunRecord? _finalizeRun(
    String runId,
    RunLifecycle lifecycle, {
    int? exitCode,
    String? statusReason,
    FailureSummary? failureSummary,
    bool saveHistory = true,
  }) {
    final ctx = _activeRuns[runId];
    if (ctx == null || ctx.terminalEmitted) return null;

    ctx.terminalEmitted = true;
    final record = ctx.record;
    record.lifecycle = lifecycle;
    record.status = lifecycleToLegacyStatus(lifecycle);
    if (statusReason != null) {
      record.statusReason = statusReason;
    }
    record.endTime = DateTime.now().toUtc().toIso8601String();
    record.endedAt = record.endTime;
    final started = DateTime.tryParse(record.startTime);
    if (started != null) {
      record.durationMs = DateTime.now().toUtc().difference(started).inMilliseconds;
    }
    if (exitCode != null) {
      record.exitCode = exitCode;
    }
    if (failureSummary != null) {
      record.failureSummary = failureSummary;
    }

    _registry.remove(runId);
    _activeRuns.remove(runId);

    _flushPendingLogs();
    _sendStatusUpdate(record);

    if (saveHistory && record.queueId == null) {
      _historyStore.save(record, _settingsStore);
    }

    ctx.onComplete?.call(record);
    return record;
  }

  void clearPendingRunnerLogs() {
    _pendingLogs.clear();
    _logFlushScheduled = false;
  }

  ActiveSessionState getActiveSessionState() {
    final records = _activeRuns.values
        .where((ctx) => !ctx.terminalEmitted)
        .map((ctx) => ctx.record)
        .toList();
    return ActiveSessionState(
      runIds: records.map((r) => r.runId).toList(),
      records: records,
    );
  }

  RunRecord startRun(
    RunConfig config, {
    void Function(RunRecord record)? onComplete,
    StartRunOptions options = const StartRunOptions(),
  }) {
    final runId = _generateRunId();
    _activeLogRunId = runId;
    if (options.clearLogs) {
      clearPendingRunnerLogs();
    }

    final (cmd, args, display) = _buildCommand(config);
    final projectName = p.basename(config.projectPath);

    final record = RunRecord(
      runId: runId,
      projectId: projectName,
      projectPath: config.projectPath,
      projectName: projectName,
      command: cmd,
      args: args,
      fullCommandForDisplay: display,
      targetFile: config.targetFile,
      targetFiles: config.targetFiles ?? const [],
      runMode: config.runMode,
      selectedDevice: config.deviceId,
      recordingId: config.recordingId,
      startTime: DateTime.now().toUtc().toIso8601String(),
      status: RunRecordStatus.running,
      lifecycle: RunLifecycle.starting,
      stdoutLog: '',
      stderrLog: '',
      combinedLog: '',
      logs: [],
      environmentSnapshot: 'PATH=${augmentedDeveloperPath()}',
      appVersion: appVersion,
      queueId: config.queueId,
      queueLabel: config.queueLabel,
      queueIndex: config.queueIndex,
      queueTotal: config.queueTotal,
      testNamePattern: config.testNamePattern,
    );

    _activeRuns[runId] = _ActiveRunContext(
      record: record,
      settingsStore: _settingsStore,
      onComplete: onComplete,
    );

    _sendStatusUpdate(record);

    unawaited(_spawnProcess(runId, cmd, args, config.projectPath));
    return record;
  }

  Future<void> _spawnProcess(
    String runId,
    String cmd,
    List<String> args,
    String projectPath,
  ) async {
    try {
      final process = await Process.start(
        cmd,
        args,
        workingDirectory: projectPath,
        environment: developerToolEnv(),
        runInShell: false,
        mode: ProcessStartMode.normal,
      );

      _registry.register(runId, process);
      _markRunRunning(runId);

      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.isEmpty) return;
        _handleLogLine(runId, LogStreamType.stdout, line);
      });

      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.isEmpty) return;
        _handleLogLine(runId, LogStreamType.stderr, line);
      });

      final exitCode = await process.exitCode;
      await _waitForProcessExit(runId, exitCode);
    } catch (e) {
      final ctx = _activeRuns[runId];
      if (ctx != null && !ctx.terminalEmitted) {
        final msg = '$e\n';
        ctx.record.stderrLog += msg;
        ctx.record.combinedLog += msg;
        _handleLogLine(runId, LogStreamType.stderr, e.toString());
        _finalizeRun(
          runId,
          RunLifecycle.failed,
          exitCode: -1,
          statusReason: e.toString(),
          failureSummary: _detectFailureSummary(
            ctx.record.combinedLog,
            ctx.record.stderrLog,
          ),
          saveHistory: ctx.record.queueId == null,
        );
      }
    }
  }

  void _handleLogLine(String runId, LogStreamType streamType, String line) {
    final ctx = _activeRuns[runId];
    if (ctx == null || ctx.terminalEmitted) return;

    final lineNumber = ctx.record.logs.length + 1;
    final event = _appendRecordLogLine(
      ctx.record,
      streamType,
      line,
      lineNumber,
      _detectLogSource(line),
    );
    _queueLog(event);
  }

  void _markRunRunning(String runId) {
    final ctx = _activeRuns[runId];
    if (ctx == null || ctx.terminalEmitted) return;
    ctx.record.lifecycle = RunLifecycle.running;
    ctx.record.status = RunRecordStatus.running;
    _sendStatusUpdate(ctx.record);
  }

  Future<void> _waitForProcessExit(String runId, int exitCode) async {
    final ctx = _activeRuns[runId];
    if (ctx == null || ctx.terminalEmitted) return;

    ctx.record.exitCode = exitCode;

    if (ctx.userStopRequested) {
      final lifecycle = userCancelLifecycle(ctx.record.runMode);
      final statusReason = ctx.stopStatusReason ??
          (ctx.forceStop ? 'Force stopped by user' : cancelledByUser);
      _finalizeRun(
        runId,
        lifecycle,
        exitCode: exitCode,
        statusReason: statusReason,
        saveHistory: ctx.record.queueId == null,
      );
      return;
    }

    final lifecycle = naturalExitLifecycle(exitCode);
    _finalizeRun(
      runId,
      lifecycle,
      exitCode: exitCode,
      failureSummary: lifecycle == RunLifecycle.failed
          ? _detectFailureSummary(ctx.record.combinedLog, ctx.record.stderrLog)
          : null,
      saveHistory: ctx.record.queueId == null,
    );
  }

  Future<RunRecord> runAndWait(
    RunConfig config, {
    StartRunOptions options = const StartRunOptions(),
  }) {
    final completer = Completer<RunRecord>();
    final record = startRun(
      config,
      onComplete: completer.complete,
      options: options,
    );
    return completer.future.catchError((_) => record);
  }

  Future<StopResult> stopRun(
    String runId, {
    StopRunOptions options = const StopRunOptions(),
  }) async {
    final ctx = _activeRuns[runId];
    if (ctx == null) {
      final result = mapStopProcessOutcomeToStopResult(
        runId: runId,
        outcome: ProcessStopOutcome.notFound,
        terminalEmitted: false,
      );
      _sendTerminalStatusForMissingRun(
        runId,
        result.lifecycle,
        result.statusReason,
      );
      return result;
    }

    ctx.userStopRequested = true;
    ctx.forceStop = options.force;
    ctx.stopStatusReason = options.statusReason;
    ctx.record.stopRequestedAt ??= DateTime.now().toUtc().toIso8601String();
    _appendSystemLog(ctx.record, 'Run stop requested');
    ctx.record.lifecycle = RunLifecycle.stopping;
    ctx.record.status = RunRecordStatus.running;
    _sendStatusUpdate(ctx.record);

    final processResult = await _registry.stop(
      runId,
      timeoutMs: 5000,
      force: options.force,
    );

    if (ctx.terminalEmitted) {
      return mapStopProcessOutcomeToStopResult(
        runId: runId,
        runMode: ctx.record.runMode,
        outcome: processResult.outcome,
        terminalEmitted: true,
        processError: processResult.error,
      );
    }

    final lifecycle = userCancelLifecycle(ctx.record.runMode);
    final statusReason = ctx.stopStatusReason ??
        (options.force ? 'Force stopped by user' : cancelledByUser);

    _finalizeRun(
      runId,
      lifecycle,
      exitCode: processResult.outcome == ProcessStopOutcome.forceKilled
          ? null
          : ctx.record.exitCode,
      statusReason: statusReason,
      saveHistory: ctx.record.queueId == null,
    );

    return mapStopProcessOutcomeToStopResult(
      runId: runId,
      runMode: ctx.record.runMode,
      outcome: processResult.outcome,
      terminalEmitted: true,
      processError: processResult.error,
    );
  }

  void _sendTerminalStatusForMissingRun(
    String runId,
    RunLifecycle lifecycle,
    String? statusReason,
  ) {
    _statusController.add(
      RunStatusUpdate(
        runId: runId,
        status: lifecycleToLegacyStatus(lifecycle),
        lifecycle: lifecycle,
        statusReason: statusReason,
        endedAt: DateTime.now().toUtc().toIso8601String(),
        endTime: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  Future<StopAllResult> stopAllRuns({StopRunOptions options = const StopRunOptions()}) async {
    final runIds = _activeRuns.keys.toList();
    final stoppedRunIds = <String>[];
    final failures = <StopAllFailure>[];

    for (final runId in runIds) {
      final result = await stopRun(runId, options: options);
      if (result.outcome != StopOutcome.failed) {
        stoppedRunIds.add(runId);
      } else {
        failures.add(
          StopAllFailure(runId: result.runId, error: result.error ?? 'Stop failed'),
        );
      }
    }

    return StopAllResult(stoppedRunIds: stoppedRunIds, failures: failures);
  }

  StopResult? interruptRun(String runId, String reason) {
    final ctx = _activeRuns[runId];
    if (ctx == null || ctx.terminalEmitted) return null;

    _appendSystemLog(ctx.record, reason);
    ctx.userStopRequested = true;
    ctx.record.stopRequestedAt ??= DateTime.now().toUtc().toIso8601String();
    ctx.record.lifecycle = RunLifecycle.stopping;
    _sendStatusUpdate(ctx.record);

    unawaited(() async {
      await _registry.stop(runId);
      if (!ctx.terminalEmitted) {
        _finalizeRun(
          runId,
          RunLifecycle.interrupted,
          statusReason: reason,
          saveHistory: ctx.record.queueId == null,
        );
      }
    }());

    return StopResult(
      runId: runId,
      outcome: StopOutcome.stopped,
      lifecycle: RunLifecycle.interrupted,
      statusReason: reason,
    );
  }

  void hotRestart(String runId) {
    if (!_registry.has(runId)) {
      throw StateError('No active run: $runId');
    }
    final ctx = _activeRuns[runId];
    if (ctx != null &&
        (ctx.record.lifecycle == RunLifecycle.starting ||
            ctx.record.lifecycle == RunLifecycle.stopping)) {
      throw StateError(
        'Hot restart is unavailable while the session is starting or stopping',
      );
    }
    _registry.sendInput(runId, 'r');
  }
}