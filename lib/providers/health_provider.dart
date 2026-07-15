import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/simulator_driver_health.dart';
import '../services/xctest_installer.dart';
import 'facade_provider.dart';
import 'runner_provider.dart';

enum HealthCheckState {
  unchecked,
  checking,
  current,
  stale,
  failed,
}

class HealthState {
  const HealthState({
    this.state = HealthCheckState.unchecked,
    this.checks = const [],
    this.warningCount,
    this.error,
  });

  final HealthCheckState state;
  final List<HealthCheck> checks;
  final int? warningCount;
  final String? error;

  HealthState copyWith({
    HealthCheckState? state,
    List<HealthCheck>? checks,
    int? warningCount,
    String? error,
    bool clearError = false,
  }) {
    return HealthState(
      state: state ?? this.state,
      checks: checks ?? this.checks,
      warningCount: warningCount ?? this.warningCount,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class HealthNotifier extends StateNotifier<HealthState> {
  HealthNotifier(this._ref) : super(const HealthState());

  final Ref _ref;

  void markStale() {
    if (state.state == HealthCheckState.unchecked) return;
    state = state.copyWith(state: HealthCheckState.stale);
  }

  void markUnchecked() {
    state = const HealthState();
  }

  /// Reinstalls the simulator driver on the selected booted device, then
  /// optionally re-runs project health checks. Returns an error message on
  /// failure, or null on success.
  Future<String?> repairDriver(String? projectPath) async {
    state = state.copyWith(state: HealthCheckState.checking, clearError: true);
    try {
      final runner = _ref.read(runnerProvider);
      final device = runner.selectedDevice;

      if (device != null && device.state == DeviceState.booted) {
        final status = await _ref
            .read(patrolStudioFacadeProvider)
            .simulator
            .repairDriver(udid: device.id, deviceType: device.type);
        if (status.state != DriverState.ready) {
          final message = status.error?.trim().isNotEmpty == true
              ? status.error!.trim()
              : 'Simulator driver failed to start after repair.';
          state = state.copyWith(
            state: HealthCheckState.failed,
            error: message,
          );
          return message;
        }
      } else {
        clearSimulatorDriverCache();
        XCTestInstaller.instance.stopSession();
        const message =
            'Select a booted iOS Simulator, then run Repair driver again.';
        state = state.copyWith(
          state: HealthCheckState.failed,
          error: message,
        );
        return message;
      }

      if (projectPath != null && projectPath.isNotEmpty) {
        await runChecks(projectPath, forceRefresh: true);
      } else {
        state = state.copyWith(
          state: HealthCheckState.current,
          clearError: true,
        );
      }
      return null;
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(
        state: HealthCheckState.failed,
        error: message,
      );
      return message;
    }
  }

  Future<void> runChecks(String projectPath,
      {bool forceRefresh = false}) async {
    state = state.copyWith(state: HealthCheckState.checking, clearError: true);
    try {
      final runner = _ref.read(runnerProvider);
      final device = runner.selectedDevice;
      final driverStatus =
          _ref.read(patrolStudioFacadeProvider).simulator.driverStatus();
      final results = await _ref.read(patrolStudioFacadeProvider).health.check(
            projectPath,
            forceRefresh: forceRefresh,
            driverStatus: driverStatus,
            hasBootedSimulator:
                device != null && device.state == DeviceState.booted,
          );
      final warnings = results
          .where(
            (c) =>
                c.status == HealthStatus.warning ||
                c.status == HealthStatus.failed,
          )
          .length;
      final failed = results.any((c) => c.status == HealthStatus.failed);
      state = state.copyWith(
        state: failed ? HealthCheckState.failed : HealthCheckState.current,
        checks: results,
        warningCount: warnings,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        state: HealthCheckState.failed,
        error: e.toString(),
      );
    }
  }
}

final healthProvider = StateNotifierProvider<HealthNotifier, HealthState>(
  (ref) => HealthNotifier(ref),
);

String formatHealthStripLabel(HealthCheckState state, int? warningCount) {
  return switch (state) {
    HealthCheckState.unchecked => 'Not checked',
    HealthCheckState.checking => 'Checking…',
    HealthCheckState.stale => warningCount == null
        ? 'Stale'
        : '$warningCount warning${warningCount == 1 ? '' : 's'} (stale)',
    HealthCheckState.failed => 'Check failed',
    HealthCheckState.current => warningCount == null
        ? 'Not checked'
        : warningCount == 0
            ? '0 warnings'
            : '$warningCount warning${warningCount == 1 ? '' : 's'}',
  };
}
