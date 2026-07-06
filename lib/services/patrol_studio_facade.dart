import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../models/models.dart';
import 'cli_env.dart';
import 'device_service.dart';
import 'external_recording_service.dart';
import 'health_service.dart';
import 'history_store.dart';
import 'patrol_runner.dart';
import 'project_scanner.dart';
import 'recent_projects_store.dart';
import 'recording_export.dart';
import 'recording_replay.dart';
import 'recordings_store.dart';
import 'run_queue.dart';
import 'settings_store.dart';
import 'simulator_driver_service.dart';
import 'test_scanner.dart';

/// Single entry point mirroring the Patrol Studio `patrolStudio` API.
class PatrolStudioFacade {
  PatrolStudioFacade._({
    required SettingsStore settingsStore,
    required HistoryStore historyStore,
    required RecentProjectsStore recentProjectsStore,
    required PatrolRunner patrolRunner,
    required RunQueueService runQueue,
    required DeviceService deviceService,
    required SimulatorDriverService simulatorDriver,
    required ExternalRecordingService externalRecording,
  })  : _settingsStore = settingsStore,
        _historyStore = historyStore,
        _recentProjectsStore = recentProjectsStore,
        _patrolRunner = patrolRunner,
        _runQueue = runQueue,
        _deviceService = deviceService,
        _simulatorDriver = simulatorDriver,
        _externalRecording = externalRecording;

  static final PatrolStudioFacade instance = () {
    final settingsStore = SettingsStore.instance;
    final historyStore = HistoryStore.instance;
    final patrolRunner = PatrolRunner(
      settingsStore: settingsStore,
      historyStore: historyStore,
    );
    final simulatorDriver = SimulatorDriverService(settingsStore: settingsStore);
    return PatrolStudioFacade._(
      settingsStore: settingsStore,
      historyStore: historyStore,
      recentProjectsStore: RecentProjectsStore.instance,
      patrolRunner: patrolRunner,
      runQueue: RunQueueService(
        patrolRunner: patrolRunner,
        settingsStore: settingsStore,
        historyStore: historyStore,
      ),
      deviceService: DeviceService(settingsStore: settingsStore),
      simulatorDriver: simulatorDriver,
      externalRecording: ExternalRecordingService(
        driver: simulatorDriver,
        settingsStore: settingsStore,
      ),
    );
  }();

  final SettingsStore _settingsStore;
  final HistoryStore _historyStore;
  final RecentProjectsStore _recentProjectsStore;
  final PatrolRunner _patrolRunner;
  final RunQueueService _runQueue;
  final DeviceService _deviceService;
  final SimulatorDriverService _simulatorDriver;
  final ExternalRecordingService _externalRecording;

  SimulatorDriverService get simulatorDriver => _simulatorDriver;
  ExternalRecordingService get externalRecordingService => _externalRecording;

  // ── Project ──────────────────────────────────────────────────────────────

  final PatrolStudioProjectApi project = PatrolStudioProjectApi._();
  final PatrolStudioRunnerApi runner = PatrolStudioRunnerApi._();
  final PatrolStudioDevicesApi devices = PatrolStudioDevicesApi._();
  final PatrolStudioHistoryApi history = PatrolStudioHistoryApi._();
  final PatrolStudioHealthApi health = PatrolStudioHealthApi._();
  final PatrolStudioSettingsApi settings = PatrolStudioSettingsApi._();
  final PatrolStudioSimulatorApi simulator = PatrolStudioSimulatorApi._();
  final PatrolStudioExternalRecordingApi externalRecording =
      PatrolStudioExternalRecordingApi._();
  final PatrolStudioRecordingsApi recordings = PatrolStudioRecordingsApi._();
}

class PatrolStudioProjectApi {
  PatrolStudioProjectApi._();

  PatrolStudioFacade get _f => PatrolStudioFacade.instance;

  Future<ProjectMetadata?> open() async {
    final home = Platform.environment['HOME'];
    final result = await FilePicker.platform
        .getDirectoryPath(
          dialogTitle: 'Open Flutter Project',
          initialDirectory: home != null && home.isNotEmpty ? home : null,
        )
        .timeout(
          const Duration(minutes: 10),
          onTimeout: () => null,
        );
    if (result == null || result.isEmpty) return null;
    return validate(result);
  }

  Future<ProjectMetadata> validate(String projectPath) async {
    return validateProject(projectPath);
  }

  Future<List<TestFile>> scan(String projectPath) async {
    final settings = _f._settingsStore.get();
    final metadata = validateProject(projectPath);
    final testDir = metadata.hasPatrol ? metadata.patrolTestDir : settings.testDirectory;
    return scanTestFiles(projectPath, testDir);
  }

  Future<String> readFile(String projectPath, String filePath) async {
    final absolute = p.isAbsolute(filePath)
        ? filePath
        : p.join(projectPath, filePath);
    return readFileContent(absolute);
  }

  Future<List<RecentProject>> getRecent() => _f._recentProjectsStore.getAll();

  Future<void> addRecent(ProjectMetadata project) =>
      _f._recentProjectsStore.addFromMetadata(project);

  Future<void> removeRecent(String path) => _f._recentProjectsStore.remove(path);
}

class PatrolStudioRunnerApi {
  PatrolStudioRunnerApi._();

  PatrolStudioFacade get _f => PatrolStudioFacade.instance;

  Future<RunRecord> start(
    RunConfig config, {
    void Function(RunRecord record)? onComplete,
  }) async =>
      _f._patrolRunner.startRun(config, onComplete: onComplete);

  Future<RunRecord> runAndWait(RunConfig config) =>
      _f._patrolRunner.runAndWait(config);

  Future<StopResult> stop(String runId) =>
      _f._patrolRunner.stopRun(runId);

  Future<StopResult> forceStop(String runId) => _f._patrolRunner.stopRun(
        runId,
        options: const StopRunOptions(force: true),
      );

  Future<StopAllResult> stopAll() => _f._patrolRunner.stopAllRuns();

  Future<ActiveSessionState> getActiveSession() async =>
      _f._patrolRunner.getActiveSessionState();

  Future<StopResult?> interruptSession(String runId, String reason) async =>
      _f._patrolRunner.interruptRun(runId, reason);

  Future<StartQueueResponse> startQueue(StartQueueRequest request) =>
      _f._runQueue.startQueue(request);

  Future<void> stopQueue([String? queueId]) => _f._runQueue.stopQueue(queueId);

  Stream<QueueStatusUpdate> onQueueStatus() => _f._runQueue.queueStatusUpdates;

  Stream<RunRecord> onQueueRunStarted() => _f._runQueue.queueRunStarted;

  Future<void> hotRestart(String runId) async {
    _f._patrolRunner.hotRestart(runId);
  }

  Future<void> clearLogs() async {
    _f._patrolRunner.clearPendingRunnerLogs();
  }

  Stream<LogEvent> onLog() => _f._patrolRunner.logEvents;

  Stream<List<LogEvent>> onLogs() => _f._patrolRunner.logBatches;

  Stream<RunStatusUpdate> onStatus() => _f._patrolRunner.statusUpdates;
}

class PatrolStudioDevicesApi {
  PatrolStudioDevicesApi._();

  PatrolStudioFacade get _f => PatrolStudioFacade.instance;

  Future<List<DeviceInfo>> list() => _f._deviceService.listDevices();

  String? get lastScanError => _f._deviceService.lastScanError;

  Future<String> boot(String udid) => _f._deviceService.bootSimulator(udid);

  Future<List<DeviceInfo>> refresh() => _f._deviceService.refresh();

  Future<String> shutdown(String udid) => _f._deviceService.shutdownSimulator(udid);
}

class PatrolStudioHistoryApi {
  PatrolStudioHistoryApi._();

  PatrolStudioFacade get _f => PatrolStudioFacade.instance;

  Future<List<RunRecord>> getAll(String projectPath) =>
      _f._historyStore.getAll(projectPath);

  Future<RunRecord?> get(String runId, String projectPath) =>
      _f._historyStore.get(runId, projectPath);

  Future<void> delete(String runId, String projectPath) =>
      _f._historyStore.delete(runId, projectPath);

  Future<void> clear(String projectPath) =>
      _f._historyStore.clear(projectPath);
}

class PatrolStudioHealthApi {
  PatrolStudioHealthApi._();

  PatrolStudioFacade get _f => PatrolStudioFacade.instance;

  Future<List<HealthCheck>> check(
    String projectPath, {
    bool forceRefresh = false,
    DriverStatus? driverStatus,
    bool hasBootedSimulator = false,
  }) {
    return runHealthChecks(
      projectPath,
      settingsStore: _f._settingsStore,
      driverStatus: driverStatus,
      hasBootedSimulator: hasBootedSimulator,
    );
  }
}

class PatrolStudioSettingsApi {
  PatrolStudioSettingsApi._();

  PatrolStudioFacade get _f => PatrolStudioFacade.instance;

  Future<AppSettings> get() async => _f._settingsStore.getAsync();

  Future<AppSettings> set(Map<String, dynamic> partial) async {
    return _f._settingsStore.updatePartial(partial);
  }

  AppSettings getDefaults() => _f._settingsStore.getDefaults();

  Future<Map<String, String>> validateTools({
    required Map<String, String> toolPaths,
  }) async {
    final errors = <String, String>{};
    for (final entry in toolPaths.entries) {
      final name = switch (entry.key) {
        'patrolPath' => 'patrol',
        'flutterPath' => 'flutter',
        'dartPath' => 'dart',
        'xcrunPath' => 'xcrun',
        _ => entry.key,
      };
      final resolved = resolveExecutable(name, configuredPath: entry.value);
      if (!p.isAbsolute(resolved) || !File(resolved).existsSync()) {
        errors[entry.key] = 'Could not resolve ${entry.value}';
      }
    }
    return errors;
  }
}

class PatrolStudioSimulatorApi {
  PatrolStudioSimulatorApi._();

  PatrolStudioFacade get _f => PatrolStudioFacade.instance;

  DriverStatus driverStatus() => _f._simulatorDriver.getDriverStatus();

  Future<DriverStatus> ensureDriver({
    required String udid,
    required DeviceType deviceType,
  }) async {
    await _f._simulatorDriver.ensureSession(udid: udid, deviceType: deviceType);
    return _f._simulatorDriver.getDriverStatus();
  }

  Future<DriverStatus> repairDriver({
    required String udid,
    required DeviceType deviceType,
  }) =>
      _f._simulatorDriver.repairDriver(udid: udid, deviceType: deviceType);

  Future<XCTestDeviceInfo> deviceInfo(String udid, DeviceType deviceType) =>
      _f._simulatorDriver.deviceInfo(udid: udid, deviceType: deviceType);

  Future<HierarchyNode> viewHierarchy(
    String udid,
    String? appId,
    DeviceType deviceType,
  ) =>
      _f._simulatorDriver.viewHierarchy(
        udid: udid,
        deviceType: deviceType,
        appId: appId,
      );

  Future<void> tap(
    String udid,
    double x,
    double y,
    DeviceType deviceType, {
    double? duration,
  }) =>
      _f._simulatorDriver.tap(
        udid: udid,
        x: x,
        y: y,
        deviceType: deviceType,
        duration: duration,
      );

  Future<void> tapElement(
    String udid,
    ElementFrame frame,
    DeviceType deviceType,
  ) =>
      _f._simulatorDriver.tapElement(
        udid: udid,
        frame: frame,
        deviceType: deviceType,
      );

  void stopDriver([String? udid]) => _f._simulatorDriver.stopSession(udid);
}

class PatrolStudioExternalRecordingApi {
  PatrolStudioExternalRecordingApi._();

  PatrolStudioFacade get _f => PatrolStudioFacade.instance;

  ExternalRecordingStatus status() => _f._externalRecording.getStatus();

  Future<ExternalRecordingStatus> start(
    String udid,
    String deviceName,
    DeviceType deviceType,
  ) =>
      _f._externalRecording.start(
        udid: udid,
        deviceName: deviceName,
        deviceType: deviceType,
      );

  Future<ExternalRecordingStatus> stop() async {
    await _f._externalRecording.stop();
    return _f._externalRecording.getStatus();
  }

  Stream<ExternalRecordingActionPayload> onAction() =>
      _f._externalRecording.actionStream;
}

class PatrolStudioRecordingsApi {
  PatrolStudioRecordingsApi._();

  PatrolStudioFacade get _f => PatrolStudioFacade.instance;
  RecordingsStore get _store => RecordingsStore.instance;

  Future<List<Recording>> getAll(String projectPath) async =>
      _store.getAll(projectPath);

  Future<Recording?> get(String recordingId, String projectPath) async =>
      _store.get(recordingId, projectPath);

  Future<Recording> save(RecordingDraft draft) async => _store.save(draft);

  Future<Recording> importRecording(String projectPath, String content) async =>
      _store.importRecording(projectPath, content);

  Future<Recording> rename(
    String recordingId,
    String projectPath,
    String name,
  ) async =>
      _store.rename(recordingId, projectPath, name);

  Future<void> delete(String recordingId, String projectPath) async =>
      _store.delete(recordingId, projectPath);

  Future<RecordingExport> export(String recordingId, String projectPath) async {
    final recording = _store.get(recordingId, projectPath);
    if (recording == null) throw Exception('Recording not found');
    return exportRecording(recording);
  }

  Future<RecordingTestFile> saveTest(
    String recordingId,
    String projectPath,
  ) async {
    final recording = _store.get(recordingId, projectPath);
    if (recording == null) throw Exception('Recording not found');

    final metadata = validateProject(projectPath);
    final testDir = Directory(p.join(projectPath, metadata.patrolTestDir));
    if (!testDir.existsSync()) testDir.createSync(recursive: true);

    final slug = _toFileSlug(recording.name);
    final filePath = _nextAvailableFilePath(
      testDir,
      '${slug}_recording_test.dart',
    );
    filePath.writeAsStringSync(toPatrolTest(recording));

    final testFile = RecordingTestFile(
      recordingId: recordingId,
      filePath: filePath.path,
      relativePath: p.relative(filePath.path, from: projectPath).replaceAll(r'\', '/'),
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );

    _store.appendGeneratedTestFile(recordingId, projectPath, testFile);
    return testFile;
  }

  Future<RecordingReplayResult> replay(
    String recordingId,
    String projectPath,
    String udid,
    DeviceType deviceType, {
    void Function()? onActionReplayed,
  }) async {
    final recording = _store.get(recordingId, projectPath);
    if (recording == null) throw Exception('Recording not found');

    final bundle = await replayRecording(
      recording: recording,
      udid: udid,
      deviceType: deviceType,
      driver: _f._simulatorDriver,
      onActionReplayed: onActionReplayed,
    );

    _store.appendReplayResult(recordingId, projectPath, bundle.result);
    _store.appendStateSnapshots(
      recordingId,
      projectPath,
      bundle.stateSnapshots,
    );

    return bundle.result;
  }
}

String _toFileSlug(String value) {
  final slug = value
      .trim()
      .toLowerCase()
      .split('')
      .map((c) => RegExp(r'[a-z0-9]').hasMatch(c) ? c : '_')
      .join();
  final trimmed = slug.replaceAll(RegExp(r'^_+|_+$'), '');
  return trimmed.isEmpty ? 'recording' : trimmed;
}

File _nextAvailableFilePath(Directory directory, String fileName) {
  final stem = p.basenameWithoutExtension(fileName);
  final ext = p.extension(fileName).isEmpty ? '.dart' : p.extension(fileName);
  var candidate = File(p.join(directory.path, fileName));
  var index = 2;
  while (candidate.existsSync()) {
    candidate = File(p.join(directory.path, '${stem}_$index$ext'));
    index++;
  }
  return candidate;
}

/// Convenience alias matching renderer `window.patrolStudio`.
final patrolStudio = PatrolStudioFacade.instance;