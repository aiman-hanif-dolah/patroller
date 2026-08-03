import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/routine_models.dart';
import '../domain/runner_helpers.dart';
import '../models/models.dart';
import '../services/routine_service.dart';
import 'app_provider.dart';
import 'log_provider.dart';
import 'runner_provider.dart';
import 'settings_provider.dart';

const _routineLogRunId = 'routine';

const _routineFailureKinds = {'failed', 'error', 'needsAttention'};

class RoutineState {
  const RoutineState({
    this.status = RoutineStatus.idle,
    this.readiness,
    this.models = const [],
    this.dependencies = const [],
    this.selectedModel,
    this.goal =
        'Explore stable user journeys, repair failing Patrol tests, and add meaningful uncovered tests.',
    this.customInstructions = '',
    this.events = const [],
    this.lastResult,
    this.pendingPermissionRequest,
    this.allowDirtyWorktree = false,
    this.error,
  });

  final RoutineStatus status;
  final RoutineReadinessReport? readiness;
  final List<OpenCodeModel> models;
  final List<ProjectDependency> dependencies;
  final String? selectedModel;
  final String goal;
  final String customInstructions;
  final List<RoutineEvent> events;
  final RoutineResult? lastResult;
  final PermissionRequest? pendingPermissionRequest;
  final bool allowDirtyWorktree;
  final String? error;

  bool get busy =>
      status == RoutineStatus.checking ||
      status == RoutineStatus.awaitingApproval ||
      status == RoutineStatus.running ||
      status == RoutineStatus.stopping;

  bool get canStartRoutine =>
      !busy &&
      selectedModel != null &&
      selectedModel!.isNotEmpty &&
      readiness != null &&
      readiness!.canStartPrepare;

  RoutineState copyWith({
    RoutineStatus? status,
    RoutineReadinessReport? readiness,
    List<OpenCodeModel>? models,
    List<ProjectDependency>? dependencies,
    String? selectedModel,
    String? goal,
    String? customInstructions,
    List<RoutineEvent>? events,
    RoutineResult? lastResult,
    PermissionRequest? pendingPermissionRequest,
    bool clearPermissionRequest = false,
    bool? allowDirtyWorktree,
    String? error,
    bool clearError = false,
    bool clearResult = false,
  }) {
    return RoutineState(
      status: status ?? this.status,
      readiness: readiness ?? this.readiness,
      models: models ?? this.models,
      dependencies: dependencies ?? this.dependencies,
      selectedModel: selectedModel ?? this.selectedModel,
      goal: goal ?? this.goal,
      customInstructions: customInstructions ?? this.customInstructions,
      events: events ?? this.events,
      lastResult: clearResult ? null : (lastResult ?? this.lastResult),
      pendingPermissionRequest: clearPermissionRequest
          ? null
          : (pendingPermissionRequest ?? this.pendingPermissionRequest),
      allowDirtyWorktree: allowDirtyWorktree ?? this.allowDirtyWorktree,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RoutineNotifier extends StateNotifier<RoutineState> {
  RoutineNotifier(this._ref) : super(const RoutineState()) {
    // Keep deferred device readiness in sync with the top-bar picker.
    _ref.listen<RunnerState>(runnerProvider, (previous, next) {
      final prev = previous?.selectedDevice;
      final curr = next.selectedDevice;
      if (prev?.id == curr?.id && prev?.state == curr?.state) return;
      if (state.readiness == null || state.busy) return;
      unawaited(refresh());
    });
  }

  final Ref _ref;
  final _service = RoutineService();

  void _emitEvent(RoutineEvent event) {
    state = state.copyWith(events: [...state.events, event]);
    final isFailure = _routineFailureKinds.contains(event.kind);
    _ref.read(logProvider.notifier).appendSystemLog(
      _routineLogRunId,
      formatRoutineEventLogLine(event),
      streamType: isFailure ? LogStreamType.stderr : LogStreamType.stdout,
    );
    // Auto-rescan test explorer when routine creates/modifies tests
    _ref.read(appProvider.notifier).scanTests();
  }

  Future<void> refresh() async {
    if (state.busy || state.status == RoutineStatus.running) return;
    final project = _ref.read(appProvider).currentProject;
    if (project == null) {
      state = state.copyWith(error: 'Open a Flutter project first');
      return;
    }
    state = state.copyWith(status: RoutineStatus.checking, clearError: true);
    try {
      final device = _ref.read(runnerProvider).selectedDevice;
      final readiness = await _service.inspect(
        projectPath: project.projectPath,
        selectedDevice: routineTargetDeviceLabel(device),
      );
      final models = await _service.openCode.listVerifiedFreeModels();
      final dependencies = await _service.projectTooling.listDependencies(
        project.projectPath,
      );
      final preferred = _ref.read(settingsProvider).settings.routineModel;
      state = state.copyWith(
        status: RoutineStatus.idle,
        readiness: readiness,
        models: models,
        dependencies: dependencies,
        selectedModel: models.any((model) => model.id == state.selectedModel)
            ? state.selectedModel
            : models.any((model) => model.id == preferred)
            ? preferred
            : (models.isEmpty ? null : models.first.id),
      );
    } catch (error) {
      state = state.copyWith(status: RoutineStatus.idle, error: '$error');
    }
  }

  void setGoal(String goal) => state = state.copyWith(goal: goal);

  void selectModel(String? model) {
    state = state.copyWith(selectedModel: model);
    if (model != null) {
      _ref.read(settingsProvider.notifier).updatePartial({
        'routineModel': model,
      });
    }
  }

  Future<void> pubGet() async {
    final project = _ref.read(appProvider).currentProject;
    if (project == null) return;
    final result = await _service.projectTooling.pubGet(project.projectPath);
    if (!result.ok) {
      state = state.copyWith(error: result.output);
      return;
    }
    await refresh();
  }

  Future<void> installOpenCode() async {
    state = state.copyWith(status: RoutineStatus.checking, clearError: true);
    final ok = await _service.openCode.installOnMac();
    if (!ok) {
      state = state.copyWith(
        status: RoutineStatus.needsAttention,
        error:
            'Could not install OpenCode. Install Homebrew or npm, then use the official package command.',
      );
      return;
    }
    await refresh();
  }

  Future<void> removeDependency(String package) async {
    final project = _ref.read(appProvider).currentProject;
    if (project == null) return;
    final result = await _service.projectTooling.removeDependency(
      project.projectPath,
      package,
    );
    if (!result.ok) {
      state = state.copyWith(error: result.output);
      return;
    }
    await refresh();
  }

  void setCustomInstructions(String instructions) =>
      state = state.copyWith(customInstructions: instructions);

  void toggleAllowDirtyWorktree(bool allow) =>
      state = state.copyWith(allowDirtyWorktree: allow);

  void respondPermission(String requestId, bool allow) {
    _service.openCode.respondPermission(id: requestId, allow: allow);
    state = state.copyWith(clearPermissionRequest: true);
    _emitEvent(
      RoutineEvent(
        time: DateTime.now(),
        kind: 'permission',
        message:
            'User ${allow ? "granted" : "denied"} permission request ($requestId)',
      ),
    );
  }

  Future<void> prepareAndStart({bool approved = false}) async {
    final project = _ref.read(appProvider).currentProject;
    final model = state.selectedModel;
    final readiness = state.readiness;
    if (project == null || readiness == null) {
      await refresh();
      return;
    }
    if (model == null || model.isEmpty) {
      state = state.copyWith(
        error: 'Select a verified zero-cost OpenCode model first',
      );
      return;
    }
    if (!approved) {
      state = state.copyWith(
        status: RoutineStatus.awaitingApproval,
        clearError: true,
      );
      return;
    }
    state = state.copyWith(
      status: RoutineStatus.running,
      events: [],
      clearError: true,
      clearResult: true,
    );
    _ref.read(logProvider.notifier).appendSystemLog(
      _routineLogRunId,
      '── Autonomous Patrol routine started ──',
    );
    final started = DateTime.now();
    try {
      final setup = await _service.prepare(readiness);
      final setupErrors = setup.where((result) => !result.ok).toList();
      if (setupErrors.isNotEmpty) {
        state = state.copyWith(
          status: RoutineStatus.needsAttention,
          error: setupErrors
              .map((result) => '${result.command}: ${result.output}')
              .join('\n'),
        );
        return;
      }

      final gitDirty = readiness.checks.any(
        (check) => check.id == 'git' && !check.ok,
      );
      if (gitDirty && !state.allowDirtyWorktree) {
        state = state.copyWith(
          status: RoutineStatus.needsAttention,
          error:
              'Git worktree has uncommitted changes. Enable “Allow dirty Git worktree” or clean the project first.',
        );
        return;
      }

      // Re-read the live top-bar selection after prepare so a booted simulator
      // chosen while readiness was stale no longer blocks Start Routine.
      final liveDevice = _ref.read(runnerProvider).selectedDevice;
      final liveDeviceLabel = routineTargetDeviceLabel(liveDevice);
      final liveDeviceArg = routineTargetDeviceArg(liveDevice);
      final readinessAfterDevice = readiness.withSelectedDevice(liveDeviceLabel);
      state = state.copyWith(readiness: readinessAfterDevice);
      if (liveDeviceArg == null) {
        state = state.copyWith(
          status: RoutineStatus.needsAttention,
          error:
              'Boot and select an iOS Simulator before running the routine. Project packages were prepared successfully.',
        );
        return;
      }

      if (readinessAfterDevice.status == RoutineReadiness.blocked) {
        state = state.copyWith(
          status: RoutineStatus.needsAttention,
          error: 'Readiness is blocked; resolve the failed checks first',
        );
        return;
      }
      final plan = RoutinePlan(
        projectPath: project.projectPath,
        goal: state.goal,
        model: model,
        deviceId: liveDeviceArg,
        customInstructions: state.customInstructions.trim().isNotEmpty
            ? state.customInstructions.trim()
            : null,
        allowDirtyWorktree: state.allowDirtyWorktree,
      );
      final reportPath = await _service.run(
        plan: plan,
        onEvent: _emitEvent,
        onPermissionRequest: (request) =>
            state = state.copyWith(pendingPermissionRequest: request),
      );
      final finished = DateTime.now();
      final success = state.events.any((event) => event.kind == 'completed');
      state = state.copyWith(
        status: success
            ? RoutineStatus.completed
            : RoutineStatus.needsAttention,
        clearPermissionRequest: true,
        lastResult: RoutineResult(
          status: success
              ? RoutineStatus.completed
              : RoutineStatus.needsAttention,
          message: success
              ? 'OpenCode completed the bounded routine'
              : 'Routine ended before verified completion',
          startedAt: started,
          finishedAt: finished,
          reportPath: reportPath,
        ),
      );
    } catch (error) {
      state = state.copyWith(
        status: RoutineStatus.needsAttention,
        clearPermissionRequest: true,
        error: '$error',
      );
    }
  }

  Future<void> stop() async {
    if (!state.busy) return;
    state = state.copyWith(status: RoutineStatus.stopping);
    await _service.openCode.stopRoutine();
    state = state.copyWith(
      status: RoutineStatus.needsAttention,
      error: 'Routine stopped by the user',
    );
  }
}

final routineProvider = StateNotifierProvider<RoutineNotifier, RoutineState>(
  (ref) => RoutineNotifier(ref),
);
