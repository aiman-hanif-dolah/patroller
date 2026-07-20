import 'dart:async' show Completer, StreamController, unawaited;

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'history_store.dart';
import 'patrol_runner.dart';
import 'process_registry.dart' as registry;
import 'queue_model.dart';
import 'report_export.dart';
import 'run_lifecycle.dart';
import 'settings_store.dart';

/// Emitted when a queue auto-exports (or fails to export) an HTML report.
class QueueReportEvent {
  const QueueReportEvent({
    required this.queueId,
    this.path,
    this.error,
    this.passed = 0,
    this.failed = 0,
    this.projectName,
    this.queueLabel,
  });

  final String queueId;
  final String? path;
  final String? error;
  final int passed;
  final int failed;
  final String? projectName;
  final String? queueLabel;

  bool get ok => path != null && error == null;
}

class RunQueueService {
  RunQueueService({
    required PatrolRunner patrolRunner,
    required SettingsStore settingsStore,
    required HistoryStore historyStore,
    registry.ProcessRegistry? processRegistry,
    ReportExportService? reportExport,
  })  : _patrolRunner = patrolRunner,
        _settingsStore = settingsStore,
        _historyStore = historyStore,
        _processRegistry = processRegistry ?? registry.processRegistry,
        _reportExport = reportExport ?? ReportExportService();

  final PatrolRunner _patrolRunner;
  final SettingsStore _settingsStore;
  final HistoryStore _historyStore;
  final registry.ProcessRegistry _processRegistry;
  final ReportExportService _reportExport;

  _ActiveQueue? _activeQueue;

  final _queueStatusController = StreamController<QueueStatusUpdate>.broadcast();
  final _queueRunStartedController = StreamController<RunRecord>.broadcast();
  final _queueReportController = StreamController<QueueReportEvent>.broadcast();

  Stream<QueueStatusUpdate> get queueStatusUpdates => _queueStatusController.stream;
  Stream<RunRecord> get queueRunStarted => _queueRunStartedController.stream;
  Stream<QueueReportEvent> get queueReportGenerated => _queueReportController.stream;

  void dispose() {
    _queueStatusController.close();
    _queueRunStartedController.close();
    _queueReportController.close();
  }

  String? getActiveQueueId() => _activeQueue?.queueId;
  bool isQueueActive() => _activeQueue != null;

  void _emitQueueStatus(_ActiveQueue queue, QueueStatus status, String? endedAt) {
    _queueStatusController.add(
      buildQueueStatusUpdate(
        queueId: queue.queueId,
        status: status,
        currentIndex: queue.currentIndex,
        total: queue.files.length,
        activeRunId: queue.activeRunId,
        results: queue.results,
        startedAt: queue.startedAt,
        endedAt: endedAt,
      ),
    );
  }

  Future<StartQueueResponse> startQueue(StartQueueRequest request) async {
    if (_activeQueue != null) {
      await stopQueue();
    }
    await _processRegistry.stopAll();

    final queueId =
        'queue_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 6)}';
    final queueLabel = request.queueLabel?.trim().isNotEmpty == true
        ? request.queueLabel!.trim()
        : 'Batch of ${request.files.length}';

    _activeQueue = _ActiveQueue(
      queueId: queueId,
      queueLabel: queueLabel,
      projectPath: request.projectPath,
      deviceId: request.deviceId,
      files: List<String>.from(request.files),
      startedAt: DateTime.now().toUtc().toIso8601String(),
    );

    unawaited(_runQueueLoop(queueId));
    return StartQueueResponse(queueId: queueId);
  }

  Future<void> stopQueue([String? queueId]) async {
    final queue = _activeQueue;
    if (queue == null) return;
    if (queueId != null && queue.queueId != queueId) return;

    queue.stopRequested = true;
    final activeRunId = queue.activeRunId;
    if (activeRunId != null) {
      await _patrolRunner.stopRun(
        activeRunId,
        options: const StopRunOptions(statusReason: cancelledByUser),
      );
    }
  }

  Future<void> _runQueueLoop(String queueId) async {
    final queue = _activeQueue;
    if (queue == null || queue.queueId != queueId) return;

    _emitQueueStatus(queue, QueueStatus.running, null);
    final settings = await _settingsStore.getAsync();
    final stopOnFirstFailure = settings.stopQueueOnFirstFailure;

    while (queue.results.length < queue.files.length &&
        shouldContinueQueue(queue.results, queue.stopRequested, stopOnFirstFailure)) {
      final index = queue.results.length;
      queue.currentIndex = index + 1;

      final record = await _runFileToCompletion(
        queue,
        queue.files[index],
        index,
        clearLogs: index == 0, // clear UI/logs for this batch only; keep within-batch
      );
      queue.activeRunId = null;
      queue.results.add(runRecordOutcome(record));
      queue.childRecords.add(record);
      _emitQueueStatus(queue, QueueStatus.running, null);
    }

    await _persistSkippedRemaining(queue);
    final endedAt = DateTime.now().toUtc().toIso8601String();
    final projectName = p.basename(queue.projectPath);
    final summary = buildQueueSummaryRecord(
      queueId: queue.queueId,
      queueLabel: queue.queueLabel,
      projectPath: queue.projectPath,
      projectName: projectName,
      deviceId: queue.deviceId,
      files: queue.files,
      results: queue.results,
      stopRequested: queue.stopRequested,
      startedAt: queue.startedAt,
      endedAt: endedAt,
      appVersion: appVersion,
      childSnapshots: buildQueueChildSnapshots(queue.childRecords),
    );

    await _historyStore.save(summary, _settingsStore);
    _emitQueueStatus(
      queue,
      queueFinalStatus(queue.results, queue.stopRequested),
      endedAt,
    );

    await _maybeAutoExportReport(queue, projectName);

    if (_activeQueue?.queueId == queueId) {
      _activeQueue = null;
    }
  }

  Future<void> _maybeAutoExportReport(
    _ActiveQueue queue,
    String projectName,
  ) async {
    final settings = await _settingsStore.getAsync();
    if (!settings.autoExportHtmlReport) return;
    if (queue.childRecords.isEmpty) return;

    try {
      final result = await _reportExport.exportFromRecords(
        projectPath: queue.projectPath,
        projectName: projectName,
        records: List<RunRecord>.from(queue.childRecords),
        queueLabel: queue.queueLabel,
        queueId: queue.queueId,
        device: queue.deviceId,
        runMode: RunMode.test.toJson(),
      );
      _queueReportController.add(
        QueueReportEvent(
          queueId: queue.queueId,
          path: result.path,
          projectName: projectName,
          queueLabel: queue.queueLabel,
          passed: result.report.scenarioPassed > 0
              ? result.report.scenarioPassed
              : result.report.targetPassedSum,
          failed: result.report.scenarioFailed > 0
              ? result.report.scenarioFailed
              : result.report.targetFailedSum,
        ),
      );
    } catch (e) {
      _queueReportController.add(
        QueueReportEvent(
          queueId: queue.queueId,
          error: e.toString(),
        ),
      );
    }
  }

  Future<RunRecord> _runFileToCompletion(
    _ActiveQueue queue,
    String file,
    int index, {
    bool clearLogs = false,
  }) async {
    final completer = Completer<RunRecord>();
    final record = _patrolRunner.startRun(
      RunConfig(
        targetFile: file,
        runMode: RunMode.test,
        projectPath: queue.projectPath,
        deviceId: queue.deviceId,
        queueId: queue.queueId,
        queueLabel: queue.queueLabel,
        queueIndex: index + 1,
        queueTotal: queue.files.length,
      ),
      onComplete: (completed) {
        var finalRecord = completed;
        if (queue.stopRequested &&
            finalRecord.status == RunRecordStatus.cancelled &&
            (finalRecord.statusReason == null || finalRecord.statusReason!.isEmpty)) {
          finalRecord.statusReason = cancelledByUser;
        }
        unawaited(_historyStore.save(finalRecord, _settingsStore));
        completer.complete(finalRecord);
      },
      // First file of a batch clears prior session logs so the report/UI only
      // reflect this Test All. Later files keep batch context without wipe.
      options: StartRunOptions(clearLogs: clearLogs),
    );

    queue.activeRunId = record.runId;
    _queueRunStartedController.add(record);
    _emitQueueStatus(queue, QueueStatus.running, null);
    return completer.future;
  }

  Future<void> _persistSkippedRemaining(_ActiveQueue queue) async {
    if (queue.results.length >= queue.files.length) return;

    final endedAt = DateTime.now().toUtc().toIso8601String();
    final skipReason = skipReasonForQueue(queue.stopRequested);
    final projectName = p.basename(queue.projectPath);

    for (var index = queue.results.length; index < queue.files.length; index++) {
      final skipRecord = buildSkippedRunRecord(
        queueId: queue.queueId,
        queueLabel: queue.queueLabel,
        projectPath: queue.projectPath,
        projectName: projectName,
        deviceId: queue.deviceId,
        targetFile: queue.files[index],
        queueIndex: index + 1,
        queueTotal: queue.files.length,
        statusReason: skipReason,
        startedAt: endedAt,
        endedAt: endedAt,
        appVersion: appVersion,
      );
      await _historyStore.save(skipRecord, _settingsStore);
      queue.results.add(QueueRunOutcome.skipped);
      queue.childRecords.add(skipRecord);
    }

    _emitQueueStatus(queue, QueueStatus.running, null);
  }
}

class _ActiveQueue {
  _ActiveQueue({
    required this.queueId,
    required this.queueLabel,
    required this.projectPath,
    this.deviceId,
    required this.files,
    required this.startedAt,
  });

  final String queueId;
  final String queueLabel;
  final String projectPath;
  final String? deviceId;
  final List<String> files;
  final String startedAt;
  final List<QueueRunOutcome> results = [];
  final List<RunRecord> childRecords = [];
  int currentIndex = 0;
  String? activeRunId;
  bool stopRequested = false;
}

