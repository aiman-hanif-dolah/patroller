import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/runner_helpers.dart';
import '../models/models.dart';
import '../services/patrol_studio_facade.dart';
import 'app_provider.dart';
import 'facade_provider.dart';
import 'failed_logs_provider.dart';
import 'health_stale.dart';
import 'log_provider.dart';


class SnackbarMessage {
  const SnackbarMessage({required this.message, required this.id});

  final String message;
  final int id;
}

class StopFailure {
  const StopFailure({required this.runId, required this.message});

  final String runId;
  final String message;
}

class RunAllContext {
  const RunAllContext({required this.total, required this.current});

  final int total;
  final int current;
}

class RunnerState {
  const RunnerState({
    this.currentRun,
    this.isRunning = false,
    this.snackbar,
    this.stopFailure,
    this.devices = const [],
    this.selectedDevice,
    this.runAllContext,
    this.queueStatus,
  });

  final RunRecord? currentRun;
  final bool isRunning;
  final SnackbarMessage? snackbar;
  final StopFailure? stopFailure;
  final List<DeviceInfo> devices;
  final DeviceInfo? selectedDevice;
  final RunAllContext? runAllContext;
  final QueueStatusUpdate? queueStatus;

  RunnerState copyWith({
    RunRecord? currentRun,
    bool? isRunning,
    SnackbarMessage? snackbar,
    StopFailure? stopFailure,
    List<DeviceInfo>? devices,
    DeviceInfo? selectedDevice,
    RunAllContext? runAllContext,
    QueueStatusUpdate? queueStatus,
    bool clearSnackbar = false,
    bool clearStopFailure = false,
    bool clearRunAllContext = false,
    bool clearQueueStatus = false,
    bool clearCurrentRun = false,
    bool clearSelectedDevice = false,
  }) {
    return RunnerState(
      currentRun: clearCurrentRun ? null : (currentRun ?? this.currentRun),
      isRunning: isRunning ?? this.isRunning,
      snackbar: clearSnackbar ? null : (snackbar ?? this.snackbar),
      stopFailure:
          clearStopFailure ? null : (stopFailure ?? this.stopFailure),
      devices: devices ?? this.devices,
      selectedDevice: clearSelectedDevice
          ? null
          : (selectedDevice ?? this.selectedDevice),
      runAllContext: clearRunAllContext
          ? null
          : (runAllContext ?? this.runAllContext),
      queueStatus:
          clearQueueStatus ? null : (queueStatus ?? this.queueStatus),
    );
  }
}

class RunnerNotifier extends StateNotifier<RunnerState> {
  RunnerNotifier(this._ref) : super(const RunnerState()) {
    _subscribe();
    syncActiveSession();
  }

  final Ref _ref;

  PatrolStudioFacade get _facade => _ref.read(patrolStudioFacadeProvider);

  void _subscribe() {
    _facade.runner.onStatus().listen(_handleStatusUpdate);
    _facade.runner.onQueueStatus().listen(_handleQueueStatus);
    _facade.runner.onQueueRunStarted().listen((record) {
      final file = record.targetFile?.split('/').last ?? 'test';
      final index = record.queueIndex ?? 0;
      final total = record.queueTotal ?? 0;
      _ref.read(logProvider.notifier).appendSystemLog(
        record.runId,
        '── Test All $index/$total: $file ──',
      );
      state = state.copyWith(currentRun: record);
    });
  }

  Future<void> syncActiveSession() async {
    final session = await _facade.runner.getActiveSession();
    if (session.runIds.isEmpty) {
      if (!state.isRunning && state.currentRun == null) return;
      _ref.read(logProvider.notifier).setActiveLogRunId(null);
      state = state.copyWith(
        isRunning: false,
        clearCurrentRun: true,
        clearRunAllContext: true,
      );
      return;
    }
    final record = session.records.first;
    _ref.read(logProvider.notifier).setActiveLogRunId(record.runId);
    state = state.copyWith(currentRun: record, isRunning: true);
  }

  Future<void> loadDevices() async {
    try {
      final devices = await _facade.devices.list();
      setDevices(devices);
      _notifyIfNoDevices(devices);
    } catch (e) {
      showSnackbar(e.toString());
    }
  }

  Future<void> refreshDevices() async {
    try {
      final devices = await _facade.devices.refresh();
      setDevices(devices);
      _notifyIfNoDevices(devices);
    } catch (e) {
      showSnackbar(e.toString());
    }
  }

  void _notifyIfNoDevices(List<DeviceInfo> devices) {
    if (devices.isNotEmpty) return;
    final detail = _facade.devices.lastScanError;
    showSnackbar(
      detail == null
          ? 'No iOS simulators found. Open Xcode Simulator, then refresh.'
          : 'Simulator scan failed: $detail',
    );
  }

  void setDevices(List<DeviceInfo> devices, {bool autoSelect = true}) {
    DeviceInfo? selected = state.selectedDevice;
    if (autoSelect && selected == null) {
      selected = pickDefaultSelectableDevice(devices);
    } else if (selected != null) {
      selected = devices.where((d) => d.id == selected!.id).firstOrNull ??
          selected;
    }
    state = state.copyWith(devices: devices, selectedDevice: selected);
  }

  void setSelectedDevice(DeviceInfo? device) {
    if (device != null && !isSelectableDevice(device)) return;
    state = state.copyWith(selectedDevice: device);
    markHealthStale(_ref);
  }

  void showSnackbar(String message) {
    state = state.copyWith(
      snackbar: SnackbarMessage(
        message: message,
        id: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  void dismissSnackbar() {
    state = state.copyWith(clearSnackbar: true);
  }

  void _handleStatusUpdate(RunStatusUpdate status) {
    final run = state.currentRun;
    if (run == null || run.runId != status.runId) return;

    run.status = status.status;
    run.lifecycle = status.lifecycle ?? run.lifecycle;
    run.durationMs = status.durationMs ?? run.durationMs;
    run.stopRequestedAt = status.stopRequestedAt ?? run.stopRequestedAt;
    run.endedAt = status.endedAt ?? run.endedAt;
    run.endTime = status.endTime ?? run.endTime;
    run.exitCode = status.exitCode ?? run.exitCode;

    final lifecycle = run.lifecycle;
    final keepRunning = lifecycle != null &&
        !isActiveLifecycle(lifecycle) &&
        state.runAllContext != null;

    state = state.copyWith(
      currentRun: run,
      isRunning: (lifecycle != null && isActiveLifecycle(lifecycle)) ||
          status.status == RunRecordStatus.running ||
          keepRunning,
      clearStopFailure:
          lifecycle != null && isActiveLifecycle(lifecycle) ? false : true,
    );

    final terminal = lifecycle != null && !isActiveLifecycle(lifecycle);
    if (terminal && run.targetFile != null) {
      _ref.read(appProvider.notifier).updateTestFileRunResult(
            run.targetFile!,
            runRecordStatusToTestStatus(status.status),
            status.durationMs,
          );
    }
    if (terminal && isFailedRunStatus(status.status)) {
      _ref.read(failedLogsProvider.notifier).captureFailure(
            record: run,
            liveLogs: _ref.read(logProvider).logs,
          );
    }
  }

  void _handleQueueStatus(QueueStatusUpdate status) {
    final running = status.status == QueueStatus.running;
    state = state.copyWith(
      queueStatus: status,
      runAllContext: running
          ? RunAllContext(
              total: status.total,
              current: status.currentIndex.clamp(1, status.total),
            )
          : null,
      isRunning: running ? true : state.isRunning,
    );

    if (!running) {
      final label = switch (status.status) {
        QueueStatus.completed =>
          'Test All finished: ${status.passedCount} passed',
        QueueStatus.stopped => 'Test All stopped',
        _ => 'Test All finished: ${status.failedCount} failed',
      };
      showSnackbar(label);
    }
  }

  List<TestFile> _filesForRunAll() {
    final app = _ref.read(appProvider);
    return runnableTestFiles(app.testFiles);
  }

  Future<DeviceInfo?> _ensureDevice() async {
    var device = state.selectedDevice;
    if (device == null) {
      await refreshDevices();
      device = state.selectedDevice;
    }
    if (device == null) {
      showSnackbar('Select an iOS Simulator first');
      return null;
    }
    if (device.state != DeviceState.booted) {
      showSnackbar('Booting ${device.name}…');
      try {
        await _facade.devices.boot(device.id);
        await refreshDevices();
        device = state.selectedDevice ?? device;
      } catch (e) {
        showSnackbar('Simulator boot failed: $e');
        return null;
      }
      if (device.state != DeviceState.booted) {
        showSnackbar('Boot the simulator before running tests');
        return null;
      }
    }
    return device;
  }

  bool _canStart() => !isSessionBusy(state.isRunning, state.currentRun);

  Future<void> runSelected() async {
    final app = _ref.read(appProvider);
    final file = app.selectedFile;
    if (file == null || !_canStart()) return;

    await _startRun(
      RunConfig(
        projectPath: app.currentProject!.projectPath,
        runMode: RunMode.test,
        targetFile: file.absolutePath,
      ),
      'Test started',
    );
  }

  Future<void> runAll() async {
    final app = _ref.read(appProvider);
    if (app.currentProject == null || !_canStart()) return;

    final files = _filesForRunAll();
    if (files.isEmpty) return;

    final device = await _ensureDevice();
    if (device == null) return;

    final log = _ref.read(logProvider.notifier);
    showSnackbar(
      'Test All started (${files.length} file${files.length == 1 ? '' : 's'})',
    );
    // Test All keeps logs across every file in the batch — only Test/Develop clear.
    log.setActiveLogRunId(null);
    state = state.copyWith(
      isRunning: true,
      runAllContext: RunAllContext(total: files.length, current: 0),
    );

    try {
      await _facade.runner.startQueue(
        StartQueueRequest(
          projectPath: app.currentProject!.projectPath,
          deviceId: device.id,
          files: files.map((f) => f.absolutePath).toList(),
          queueLabel:
              'Test All: ${files.length} file${files.length == 1 ? '' : 's'}',
        ),
      );
    } catch (e) {
      showSnackbar(e.toString());
      state = state.copyWith(isRunning: false, clearRunAllContext: true);
    }
  }

  Future<void> develop() async {
    final app = _ref.read(appProvider);
    final file = app.selectedFile;
    if (file == null || !_canStart()) return;

    await _startRun(
      RunConfig(
        projectPath: app.currentProject!.projectPath,
        runMode: RunMode.develop,
        targetFile: file.absolutePath,
      ),
      'Develop started',
    );
  }

  List<String> _developSuiteQueue = [];

  Future<void> developSuite() async {
    final app = _ref.read(appProvider);
    if (app.currentProject == null ||
        !_canStart() ||
        app.testFiles.isEmpty) {
      return;
    }

    final files = _filesForRunAll();
    if (files.isEmpty) return;

    _developSuiteQueue = files.map((f) => f.absolutePath).toList();

    showSnackbar(
      files.length == 1
          ? 'Develop All started'
          : 'Develop All started (${files.length} files)',
    );

    await _startNextDevelopSuiteFileInternal();
  }

  Future<void> _startNextDevelopSuiteFileInternal() async {
    if (_developSuiteQueue.isEmpty) {
      state = state.copyWith(isRunning: false, clearCurrentRun: true);
      return;
    }

    state = state.copyWith(isRunning: false, clearCurrentRun: true);

    final nextPath = _developSuiteQueue.removeAt(0);
    final app = _ref.read(appProvider);
    final nextFile = app.testFiles.firstWhere((f) => f.absolutePath == nextPath);

    await _startRun(
      RunConfig(
        projectPath: app.currentProject!.projectPath,
        runMode: RunMode.developSuite,
        targetFile: nextFile.absolutePath,
        targetFiles: [nextFile.absolutePath, ..._developSuiteQueue],
      ),
      '',
    );
  }

  Future<void> _startRun(RunConfig config, String message) async {
    if (!_canStart()) {
      showSnackbar('Stop the active Develop session first');
      return;
    }

    final device = await _ensureDevice();
    if (device == null) return;

    final log = _ref.read(logProvider.notifier);
    showSnackbar(message);
    log.resetLogUiState();
    await log.clearLogs();
    log.setActiveLogRunId(null);
    state = state.copyWith(isRunning: true, clearStopFailure: true);

    try {
      final record = await _facade.runner.start(
        RunConfig(
          projectPath: config.projectPath,
          runMode: config.runMode,
          targetFile: config.targetFile,
          targetFiles: config.targetFiles,
          excludedFiles: config.excludedFiles,
          deviceId: device.id,
          queueLabel: config.queueLabel,
        ),
        onComplete: (completed) {
          if (completed.runMode == RunMode.developSuite &&
              _developSuiteQueue.isNotEmpty) {
            Future.microtask(_startNextDevelopSuiteFileInternal);
          } else if (completed.runMode == RunMode.developSuite &&
              _developSuiteQueue.isEmpty) {
            state = state.copyWith(isRunning: false, clearCurrentRun: true);
          }
        },
      );
      log.setActiveLogRunId(record.runId);
      state = state.copyWith(currentRun: record);
    } catch (e) {
      showSnackbar(e.toString());
      state = state.copyWith(isRunning: false);
    }
  }

  Future<void> stop() async {
    final queue = state.queueStatus;
    if (queue != null && queue.status == QueueStatus.running) {
      try {
        await _facade.runner.stopQueue(queue.queueId);
      } catch (e) {
        showSnackbar(e.toString());
      }
    }

    final run = state.currentRun;
    if (run != null && isSessionBusy(state.isRunning, run)) {
      _ref.read(logProvider.notifier).appendSystemLog(run.runId, 'Stop requested');
      try {
        final result = await _facade.runner.stop(run.runId);
        if (result.outcome == StopOutcome.failed) {
          state = state.copyWith(
            stopFailure: StopFailure(
              runId: run.runId,
              message: result.error ?? 'Stop failed',
            ),
          );
        } else {
          state = state.copyWith(
            isRunning: false,
            clearStopFailure: true,
            clearRunAllContext: true,
          );
        }
      } catch (e) {
        state = state.copyWith(
          stopFailure: StopFailure(runId: run.runId, message: e.toString()),
        );
      }
    } else {
      await _facade.runner.stopAll();
      state = state.copyWith(
        isRunning: false,
        clearRunAllContext: true,
      );
    }
  }

  Future<void> hotRestart() async {
    final run = state.currentRun;
    final block = hotRestartDisabledReason(
      isRunning: state.isRunning,
      currentRun: run,
    );
    if (block != null) {
      showSnackbar(block);
      return;
    }

    try {
      await _facade.runner.hotRestart(run!.runId);
      _ref.read(logProvider.notifier).appendSystemLog(
        run.runId,
        'Hot restart requested',
      );
    } catch (e) {
      showSnackbar(e.toString());
    }
  }

  Future<void> forceStop() async {
    final run = state.currentRun;
    if (run == null) return;
    try {
      await _facade.runner.forceStop(run.runId);
      state = state.copyWith(
        isRunning: false,
        clearStopFailure: true,
        clearRunAllContext: true,
      );
    } catch (e) {
      showSnackbar(e.toString());
    }
  }

  Future<void> bootSimulator() async {
    final device = state.selectedDevice;
    if (device == null) return;
    await bootDevice(device.id);
  }

  Future<void> bootDevice(String deviceId) async {
    final device =
        state.devices.where((d) => d.id == deviceId).firstOrNull;
    if (device == null || device.state != DeviceState.shutdown) return;
    try {
      await _facade.devices.boot(device.id);
      await refreshDevices();
      final updated =
          state.devices.where((d) => d.id == deviceId).firstOrNull;
      if (updated != null) {
        setSelectedDevice(updated);
      }
    } catch (e) {
      showSnackbar(e.toString());
    }
  }

  Future<void> shutdownSimulator() async {
    final device = state.selectedDevice;
    if (device == null || device.state != DeviceState.booted) return;
    try {
      await _facade.devices.shutdown(device.id);
      await refreshDevices();
    } catch (e) {
      showSnackbar(e.toString());
    }
  }
}

final runnerProvider = StateNotifierProvider<RunnerNotifier, RunnerState>(
  (ref) => RunnerNotifier(ref),
);