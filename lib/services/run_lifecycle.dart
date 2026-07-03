import '../models/models.dart';
import 'process_registry.dart';

const String cancelledByUser = 'cancelled by user';

RunRecordStatus lifecycleToLegacyStatus(RunLifecycle lifecycle) {
  switch (lifecycle) {
    case RunLifecycle.starting:
    case RunLifecycle.running:
    case RunLifecycle.stopping:
      return RunRecordStatus.running;
    case RunLifecycle.passed:
      return RunRecordStatus.passed;
    case RunLifecycle.failed:
      return RunRecordStatus.failed;
    case RunLifecycle.cancelled:
    case RunLifecycle.stopped:
    case RunLifecycle.interrupted:
      return RunRecordStatus.cancelled;
  }
}

RunLifecycle naturalExitLifecycle(int? exitCode, [String? signal]) {
  if (signal != null && signal.isNotEmpty) {
    return RunLifecycle.failed;
  }
  if (exitCode == 0) {
    return RunLifecycle.passed;
  }
  return RunLifecycle.failed;
}

RunLifecycle userCancelLifecycle(RunMode runMode) {
  switch (runMode) {
    case RunMode.develop:
    case RunMode.developSuite:
      return RunLifecycle.stopped;
    default:
      return RunLifecycle.cancelled;
  }
}

StopResult mapStopProcessOutcomeToStopResult({
  required String runId,
  RunMode? runMode,
  required ProcessStopOutcome outcome,
  required bool terminalEmitted,
  String? processError,
}) {
  final lifecycle = switch (outcome) {
    ProcessStopOutcome.notFound => RunLifecycle.stopped,
    ProcessStopOutcome.alreadyExited => RunLifecycle.stopped,
    ProcessStopOutcome.stopped ||
    ProcessStopOutcome.forceKilled =>
      runMode != null ? userCancelLifecycle(runMode) : RunLifecycle.cancelled,
    ProcessStopOutcome.failed => RunLifecycle.failed,
  };

  final stopOutcome = switch (outcome) {
    ProcessStopOutcome.notFound => StopOutcome.notFound,
    ProcessStopOutcome.alreadyExited => StopOutcome.stopped,
    ProcessStopOutcome.stopped => StopOutcome.stopped,
    ProcessStopOutcome.forceKilled => StopOutcome.forceKilled,
    ProcessStopOutcome.failed => StopOutcome.failed,
  };

  return StopResult(
    runId: runId,
    outcome: stopOutcome,
    lifecycle: lifecycle,
    statusReason: terminalEmitted && outcome != ProcessStopOutcome.notFound
        ? cancelledByUser
        : null,
    error: processError,
  );
}