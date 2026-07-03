import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import 'facade_provider.dart';

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

  Future<void> runChecks(String projectPath, {bool forceRefresh = false}) async {
    state = state.copyWith(state: HealthCheckState.checking, clearError: true);
    try {
      final results = await _ref
          .read(patrolStudioFacadeProvider)
          .health
          .check(projectPath, forceRefresh: forceRefresh);
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

String formatHealthStripLabel(HealthState health) {
  return switch (health.state) {
    HealthCheckState.unchecked => 'Not checked',
    HealthCheckState.checking => 'Checking…',
    HealthCheckState.stale => health.warningCount == null
        ? 'Stale'
        : '${health.warningCount} warning${health.warningCount == 1 ? '' : 's'} (stale)',
    HealthCheckState.failed => 'Check failed',
    HealthCheckState.current => health.warningCount == null
        ? '—'
        : health.warningCount == 0
            ? '0 warnings'
            : '${health.warningCount} warning${health.warningCount == 1 ? '' : 's'}',
  };
}