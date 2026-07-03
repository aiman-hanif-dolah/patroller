import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/recording_enrichment.dart';
import '../domain/recording_import_validation.dart';
import '../domain/runner_helpers.dart';
import '../domain/state_snapshot.dart';
import '../models/models.dart';
import 'facade_provider.dart';
import 'runner_provider.dart';

const _enrichmentTimeoutMs = 4000;

class RecordingState {
  const RecordingState({
    this.recordings = const [],
    this.activeActions = const [],
    this.activeStateSnapshots = const [],
    this.startedAt,
    this.lastActionAt,
    this.isRecording = false,
    this.recordingSource = RecordingSource.embedded,
    this.isReplaying = false,
    this.replayResult,
    this.error,
    this.externalStatus,
  });

  final List<Recording> recordings;
  final List<RecordingAction> activeActions;
  final List<RecordingStateSnapshot> activeStateSnapshots;
  final int? startedAt;
  final int? lastActionAt;
  final bool isRecording;
  final RecordingSource recordingSource;
  final bool isReplaying;
  final RecordingReplayResult? replayResult;
  final String? error;
  final ExternalRecordingStatus? externalStatus;

  RecordingState copyWith({
    List<Recording>? recordings,
    List<RecordingAction>? activeActions,
    List<RecordingStateSnapshot>? activeStateSnapshots,
    int? startedAt,
    int? lastActionAt,
    bool? isRecording,
    RecordingSource? recordingSource,
    bool? isReplaying,
    RecordingReplayResult? replayResult,
    String? error,
    ExternalRecordingStatus? externalStatus,
    bool clearStartedAt = false,
    bool clearLastActionAt = false,
    bool clearReplayResult = false,
    bool clearError = false,
    bool clearExternalStatus = false,
  }) {
    return RecordingState(
      recordings: recordings ?? this.recordings,
      activeActions: activeActions ?? this.activeActions,
      activeStateSnapshots:
          activeStateSnapshots ?? this.activeStateSnapshots,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      lastActionAt:
          clearLastActionAt ? null : (lastActionAt ?? this.lastActionAt),
      isRecording: isRecording ?? this.isRecording,
      recordingSource: recordingSource ?? this.recordingSource,
      isReplaying: isReplaying ?? this.isReplaying,
      replayResult:
          clearReplayResult ? null : (replayResult ?? this.replayResult),
      error: clearError ? null : (error ?? this.error),
      externalStatus: clearExternalStatus
          ? null
          : (externalStatus ?? this.externalStatus),
    );
  }
}

class _EnrichmentState {
  int session = 0;
  HierarchyNode? lastHierarchy;
  String? lastFingerprint;
  XCTestDeviceInfo? deviceInfo;
  Future<void> chain = Future<void>.value();
}

class RecordingNotifier extends StateNotifier<RecordingState> {
  RecordingNotifier(this._ref) : super(const RecordingState()) {
    _subscribeExternalActions();
  }

  final Ref _ref;
  final _enrichment = _EnrichmentState();
  StreamSubscription<ExternalRecordingActionPayload>? _actionSub;

  void _subscribeExternalActions() {
    _actionSub?.cancel();
    _actionSub = _ref
        .read(patrolStudioFacadeProvider)
        .externalRecording
        .onAction()
        .listen(_handleExternalAction);
  }

  void _handleExternalAction(ExternalRecordingActionPayload payload) {
    recordAction(
      payload.type,
      x: payload.x,
      y: payload.y,
      toX: payload.toX,
      toY: payload.toY,
      durationSec: payload.durationSec,
      text: payload.text,
      key: payload.key,
    );
  }

  Future<void> loadRecordings(String projectPath) async {
    try {
      final recordings = await _ref
          .read(patrolStudioFacadeProvider)
          .recordings
          .getAll(projectPath);
      state = state.copyWith(recordings: recordings, clearError: true);
    } catch (e) {
      final message = e.toString();
      state = state.copyWith(error: message);
      _ref.read(runnerProvider.notifier).showSnackbar(message);
    }
  }

  void resetForProjectSwitch() {
    state = state.copyWith(
      recordings: const [],
      clearReplayResult: true,
      clearError: true,
    );
  }

  Future<void> startRecording() async {
    final device = _ref.read(runnerProvider).selectedDevice;
    if (device == null) {
      const message = 'Select a booted iOS Simulator before recording.';
      state = state.copyWith(error: message);
      _ref.read(runnerProvider.notifier).showSnackbar(message);
      return;
    }
    if (!isSelectableDevice(device)) {
      const message = 'Recording requires a supported iOS Simulator.';
      state = state.copyWith(error: message);
      _ref.read(runnerProvider.notifier).showSnackbar(message);
      return;
    }
    if (device.state != DeviceState.booted) {
      const message = 'Boot the simulator before recording.';
      state = state.copyWith(error: message);
      _ref.read(runnerProvider.notifier).showSnackbar(message);
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    _enrichment.session++;
    _enrichment.lastHierarchy = null;
    _enrichment.lastFingerprint = null;

    state = state.copyWith(
      activeActions: const [],
      activeStateSnapshots: const [],
      startedAt: now,
      lastActionAt: now,
      isRecording: true,
      recordingSource: RecordingSource.external,
      clearReplayResult: true,
      clearError: true,
    );
    _captureInitialState(_enrichment.session);

    try {
      final status = await _ref.read(patrolStudioFacadeProvider).externalRecording.start(
            device.id,
            device.name,
            device.type,
          );
      if (status.error != null) {
        state = state.copyWith(error: status.error, externalStatus: status);
        _ref.read(runnerProvider.notifier).showSnackbar(status.error!);
      } else {
        state = state.copyWith(externalStatus: status);
      }
    } catch (e) {
      final message =
          e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e';
      state = state.copyWith(error: message);
      _ref.read(runnerProvider.notifier).showSnackbar(message);
    }
  }

  Future<void> cancelRecording() async {
    _enrichment.session++;
    _enrichment.lastHierarchy = null;
    _enrichment.lastFingerprint = null;
    try {
      await _ref.read(patrolStudioFacadeProvider).externalRecording.stop();
    } catch (_) {}
    state = state.copyWith(
      activeActions: const [],
      activeStateSnapshots: const [],
      clearStartedAt: true,
      clearLastActionAt: true,
      isRecording: false,
      recordingSource: RecordingSource.embedded,
      clearError: true,
      clearExternalStatus: true,
    );
  }

  void recordAction(
    RecordingActionType type, {
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
  }) {
    final current = state;
    if (!current.isRecording ||
        current.startedAt == null ||
        current.lastActionAt == null) {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final action = RecordingAction(
      id: _createActionId(),
      type: type,
      timestampMs: now - current.startedAt!,
      delayMs: (now - current.lastActionAt!).clamp(0, 1 << 31),
      x: x,
      y: y,
      toX: toX,
      toY: toY,
      durationSec: durationSec,
      text: text,
      key: key,
      targetLabel: targetLabel,
      targetType: targetType,
      targetFrame: targetFrame,
    );

    state = state.copyWith(
      activeActions: [...current.activeActions, action],
      lastActionAt: now,
    );

    _enrichRecordedAction(action, _enrichment.session);
  }

  Future<Recording?> saveRecording({
    required String projectPath,
    required DeviceInfo? selectedDevice,
    required List<LogEvent> logs,
    String? name,
    required RecordingEnvironmentProfile environmentProfile,
  }) async {
    final current = state;
    if (current.startedAt == null || current.activeActions.isEmpty) {
      return null;
    }

    try {
      final recording = await _ref.read(patrolStudioFacadeProvider).recordings.save(
            RecordingDraft(
              name: name?.trim().isNotEmpty == true
                  ? name!.trim()
                  : 'Recording ${DateTime.now().toLocal()}',
              projectPath: projectPath,
              deviceName: selectedDevice?.name,
              deviceType: selectedDevice?.type,
              environmentProfile: environmentProfile,
              durationMs:
                  DateTime.now().millisecondsSinceEpoch - current.startedAt!,
              actions: current.activeActions,
              logs: _toRecordingLogs(logs),
              stateSnapshots: current.activeStateSnapshots,
            ),
          );

      _enrichment.session++;
      _enrichment.lastHierarchy = null;
      _enrichment.lastFingerprint = null;
      try {
        await _ref.read(patrolStudioFacadeProvider).externalRecording.stop();
      } catch (_) {}

      state = state.copyWith(
        recordings: [recording, ...current.recordings],
        activeActions: const [],
        activeStateSnapshots: const [],
        clearStartedAt: true,
        clearLastActionAt: true,
        isRecording: false,
        recordingSource: RecordingSource.embedded,
        clearError: true,
        clearExternalStatus: true,
      );
      return recording;
    } catch (e) {
      final message = e.toString();
      state = state.copyWith(error: message);
      _ref.read(runnerProvider.notifier).showSnackbar(message);
      return null;
    }
  }

  Future<Recording?> importRecording(String projectPath, String content) async {
    try {
      final recording = await _ref
          .read(patrolStudioFacadeProvider)
          .recordings
          .importRecording(projectPath, content);
      state = state.copyWith(
        recordings: [recording, ...state.recordings],
        clearError: true,
      );
      return recording;
    } catch (e) {
      final message = sanitizeRecordingImportError(e);
      state = state.copyWith(error: message);
      _ref.read(runnerProvider.notifier).showSnackbar(message);
      return null;
    }
  }

  Future<Recording?> renameRecording(
    String recordingId,
    String projectPath,
    String name,
  ) async {
    try {
      final updated = await _ref
          .read(patrolStudioFacadeProvider)
          .recordings
          .rename(recordingId, projectPath, name);
      state = state.copyWith(
        recordings: state.recordings
            .map((r) => r.id == recordingId ? updated : r)
            .toList(),
        clearError: true,
      );
      return updated;
    } catch (e) {
      final message = e.toString();
      state = state.copyWith(error: message);
      _ref.read(runnerProvider.notifier).showSnackbar(message);
      return null;
    }
  }

  Future<void> deleteRecording(String recordingId, String projectPath) async {
    try {
      await _ref
          .read(patrolStudioFacadeProvider)
          .recordings
          .delete(recordingId, projectPath);
      state = state.copyWith(
        recordings:
            state.recordings.where((r) => r.id != recordingId).toList(),
        clearError: true,
      );
    } catch (e) {
      final message = e.toString();
      state = state.copyWith(error: message);
      _ref.read(runnerProvider.notifier).showSnackbar(message);
    }
  }

  Future<RecordingExport?> exportRecording(
    String recordingId,
    String projectPath,
  ) async {
    try {
      final exported = await _ref
          .read(patrolStudioFacadeProvider)
          .recordings
          .export(recordingId, projectPath);
      state = state.copyWith(clearError: true);
      return exported;
    } catch (e) {
      final message = e.toString();
      state = state.copyWith(error: message);
      _ref.read(runnerProvider.notifier).showSnackbar(message);
      return null;
    }
  }

  Future<RecordingTestFile?> saveTestFile(
    String recordingId,
    String projectPath,
  ) async {
    try {
      final testFile = await _ref
          .read(patrolStudioFacadeProvider)
          .recordings
          .saveTest(recordingId, projectPath);
      state = state.copyWith(
        clearError: true,
        recordings: state.recordings.map((recording) {
          if (recording.id != recordingId) return recording;
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
            actions: recording.actions,
            logs: recording.logs,
            stateSnapshots: recording.stateSnapshots,
            replayResults: recording.replayResults,
            generatedTestFiles: [
              testFile,
              ...recording.generatedTestFiles,
            ].take(20).toList(),
          );
        }).toList(),
      );
      return testFile;
    } catch (e) {
      final message = e.toString();
      state = state.copyWith(error: message);
      _ref.read(runnerProvider.notifier).showSnackbar(message);
      return null;
    }
  }

  Future<void> replayRecording(
    Recording recording,
    DeviceInfo? selectedDevice,
  ) async {
    if (selectedDevice == null) {
      const message =
          'Select a booted iOS Simulator before replaying a recording.';
      state = state.copyWith(error: message);
      _ref.read(runnerProvider.notifier).showSnackbar(message);
      return;
    }
    if (!isSelectableDevice(selectedDevice)) {
      const message = 'Replay requires a supported iOS Simulator.';
      state = state.copyWith(error: message);
      _ref.read(runnerProvider.notifier).showSnackbar(message);
      return;
    }
    if (selectedDevice.state != DeviceState.booted) {
      const message = 'Boot the simulator before replaying a recording.';
      state = state.copyWith(error: message);
      _ref.read(runnerProvider.notifier).showSnackbar(message);
      return;
    }

    state = state.copyWith(isReplaying: true, clearReplayResult: true, clearError: true);
    try {
      final result = await _ref.read(patrolStudioFacadeProvider).recordings.replay(
            recording.id,
            recording.projectPath,
            selectedDevice.id,
            selectedDevice.type,
          );
      state = state.copyWith(
        replayResult: result,
        error: result.error,
        recordings: state.recordings.map((item) {
          if (item.id != recording.id) return item;
          return Recording(
            id: item.id,
            name: item.name,
            projectPath: item.projectPath,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
            deviceName: item.deviceName,
            deviceType: item.deviceType,
            environmentProfile: item.environmentProfile,
            actionCount: item.actionCount,
            durationMs: item.durationMs,
            actions: item.actions,
            logs: item.logs,
            stateSnapshots: item.stateSnapshots,
            replayResults: [result, ...item.replayResults].take(20).toList(),
            generatedTestFiles: item.generatedTestFiles,
          );
        }).toList(),
      );
    } catch (e) {
      final message = e.toString();
      state = state.copyWith(error: message);
      _ref.read(runnerProvider.notifier).showSnackbar(message);
    } finally {
      state = state.copyWith(isReplaying: false);
    }
  }

  void _patchAction(String actionId, RecordingAction Function(RecordingAction) patch) {
    state = state.copyWith(
      activeActions: state.activeActions
          .map((a) => a.id == actionId ? patch(a) : a)
          .toList(),
    );
  }

  void _captureInitialState(int session) {
    _enqueueEnrichment(() async {
      if (_enrichment.session != session || !state.isRecording) return;
      _enrichment.deviceInfo = await _fetchDeviceInfo();
      final hierarchy = await _fetchHierarchy();
      if (_enrichment.session != session || hierarchy == null) return;
      final startedAt = state.startedAt ?? DateTime.now().millisecondsSinceEpoch;
      final snapshot = deriveStateSnapshot(
        hierarchy,
        'snap_start_$session',
        DateTime.now().millisecondsSinceEpoch - startedAt,
      );
      _enrichment.lastHierarchy = hierarchy;
      _enrichment.lastFingerprint = snapshot.screenFingerprint;
      if (!state.isRecording) return;
      state = state.copyWith(
        activeStateSnapshots: [...state.activeStateSnapshots, snapshot],
      );
    });
  }

  void _enrichRecordedAction(RecordingAction action, int session) {
    if (action.targetLabel == null) {
      final target = deriveActionTarget(
        action,
        _enrichment.lastHierarchy,
        _enrichment.deviceInfo,
      );
      if (target.targetLabel != null || target.targetFrame != null) {
        _patchAction(
          action.id,
          (a) => a.copyWith(
            targetLabel: target.targetLabel ?? a.targetLabel,
            targetType: target.targetType ?? a.targetType,
            targetFrame: target.targetFrame ?? a.targetFrame,
          ),
        );
      }
    }

    _enqueueEnrichment(() async {
      if (_enrichment.session != session) return;
      final hierarchy = await _fetchHierarchy();
      if (_enrichment.session != session || hierarchy == null) return;
      final startedAt = state.startedAt ?? DateTime.now().millisecondsSinceEpoch;
      final observation = observeStateAfterAction(
        hierarchy,
        _enrichment.lastFingerprint,
        'snap_${action.id}',
        DateTime.now().millisecondsSinceEpoch - startedAt,
      );
      _enrichment.lastHierarchy = hierarchy;
      _enrichment.lastFingerprint = observation.screenFingerprint;
      if (!state.isRecording) return;
      _patchAction(
        action.id,
        (a) => a.copyWith(
          screenFingerprint: observation.screenFingerprint,
          stateChanged: observation.stateChanged,
          stateSummary: observation.stateSummary,
        ),
      );
      if (observation.snapshot != null) {
        state = state.copyWith(
          activeStateSnapshots: [
            ...state.activeStateSnapshots,
            observation.snapshot!,
          ],
        );
      }
    });
  }

  void _enqueueEnrichment(Future<void> Function() work) {
    _enrichment.chain = _enrichment.chain.then((_) => work(), onError: (_) => work());
  }

  Future<HierarchyNode?> _fetchHierarchy() async {
    final device = _ref.read(runnerProvider).selectedDevice;
    if (device == null) return null;
    try {
      return await _ref
          .read(patrolStudioFacadeProvider)
          .simulator
          .viewHierarchy(device.id, null, device.type)
          .timeout(const Duration(milliseconds: _enrichmentTimeoutMs));
    } catch (_) {
      return null;
    }
  }

  Future<XCTestDeviceInfo?> _fetchDeviceInfo() async {
    final device = _ref.read(runnerProvider).selectedDevice;
    if (device == null) return null;
    try {
      return await _ref
          .read(patrolStudioFacadeProvider)
          .simulator
          .deviceInfo(device.id, device.type)
          .timeout(const Duration(milliseconds: _enrichmentTimeoutMs));
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _actionSub?.cancel();
    super.dispose();
  }
}

String _createActionId() {
  return 'act_${DateTime.now().millisecondsSinceEpoch}_'
      '${DateTime.now().microsecond.toRadixString(36)}';
}

List<RecordingLogSnapshot> _toRecordingLogs(List<LogEvent> logs) {
  return logs
      .take(500)
      .map(
        (log) => RecordingLogSnapshot(
          timestamp: log.timestamp,
          runId: log.runId,
          streamType: log.streamType,
          text: log.text,
          lineNumber: log.lineNumber,
        ),
      )
      .toList();
}

final recordingProvider =
    StateNotifierProvider<RecordingNotifier, RecordingState>(
  (ref) => RecordingNotifier(ref),
);