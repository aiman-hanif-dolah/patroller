import '../models/models.dart';

const simulatorDriverRepairHint =
    'Reinstall Patroller or run scripts/build-simulator-driver.sh, then use Repair driver in Health.';

class SimulatorDriverReadiness {
  const SimulatorDriverReadiness({
    required this.embeddedPreviewReady,
    required this.embeddedRecordingReady,
    required this.canInspect,
    required this.userMessage,
    required this.fixInstruction,
    this.showRepairAction = false,
    this.allowExternalFallback = false,
  });

  final bool embeddedPreviewReady;
  final bool embeddedRecordingReady;
  final bool canInspect;
  final String userMessage;
  final String fixInstruction;
  final bool showRepairAction;
  final bool allowExternalFallback;
}

SimulatorDriverReadiness resolveSimulatorDriverReadiness({
  required bool hasBootedSimulator,
  required bool runnerArtifactsAvailable,
  required bool inputMonitorBundled,
  DriverStatus? driverStatus,
}) {
  if (!inputMonitorBundled) {
    return const SimulatorDriverReadiness(
      embeddedPreviewReady: false,
      embeddedRecordingReady: false,
      canInspect: false,
      userMessage:
          'Simulator input monitor is missing from this Patroller install.',
      fixInstruction: 'Reinstall Patroller to bundle simulator-input-monitor.',
      showRepairAction: false,
      allowExternalFallback: false,
    );
  }

  if (!runnerArtifactsAvailable) {
    return const SimulatorDriverReadiness(
      embeddedPreviewReady: false,
      embeddedRecordingReady: false,
      canInspect: false,
      userMessage: 'Simulator driver bundle is missing from this Patroller install.',
      fixInstruction: simulatorDriverRepairHint,
      showRepairAction: true,
      allowExternalFallback: false,
    );
  }

  if (!hasBootedSimulator) {
    return const SimulatorDriverReadiness(
      embeddedPreviewReady: false,
      embeddedRecordingReady: false,
      canInspect: false,
      userMessage: 'Boot an iOS Simulator to record actions.',
      fixInstruction:
          'Use the device picker below to boot a simulator, then click Record.',
      allowExternalFallback: false,
    );
  }

  if (driverStatus?.state == DriverState.starting) {
    return const SimulatorDriverReadiness(
      embeddedPreviewReady: false,
      embeddedRecordingReady: false,
      canInspect: false,
      userMessage: 'Starting simulator driver for recording…',
      fixInstruction: 'Wait a few seconds, then click Record again.',
      allowExternalFallback: false,
    );
  }

  final driverError = driverStatus?.error?.trim() ?? '';
  if (driverError.toLowerCase().contains('missing')) {
    return SimulatorDriverReadiness(
      embeddedPreviewReady: false,
      embeddedRecordingReady: false,
      canInspect: false,
      userMessage: driverError,
      fixInstruction: simulatorDriverRepairHint,
      showRepairAction: true,
      allowExternalFallback: false,
    );
  }

  return const SimulatorDriverReadiness(
    embeddedPreviewReady: false,
    embeddedRecordingReady: false,
    canInspect: false,
    userMessage:
        'Interact in Simulator.app — taps and swipes are recorded automatically.',
    fixInstruction:
        'Click Record, then use the Simulator window. Patroller maps screen coordinates to the selected device.',
    allowExternalFallback: true,
  );
}

String recordingInstructionCopy(SimulatorDriverReadiness readiness) {
  if (readiness.allowExternalFallback) {
    return readiness.userMessage;
  }
  if (readiness.showRepairAction) {
    return '${readiness.userMessage} ${readiness.fixInstruction}';
  }
  return readiness.userMessage;
}

String recordingActiveCopy({
  required SimulatorDriverReadiness readiness,
  required int actionCount,
}) {
  if (readiness.allowExternalFallback) {
    return '$actionCount actions captured from Simulator.app. Logs attach on save.';
  }
  return 'Recording is unavailable until a booted simulator and driver are ready.';
}

String historyFilterLabel(String filter) {
  return switch (filter) {
    'all' => 'All',
    'failed' => 'Failed',
    'passed' => 'Passed',
    'cancelled' => 'Cancelled',
    'batches' => 'Batches',
    _ => filter,
  };
}

String testsFilterLabel(String filter) {
  return switch (filter) {
    'all' => 'All',
    'passed' => 'Passed',
    'failed' => 'Failed',
    'never' => 'Never run',
    'selected' => 'Selected',
    'runnable' => 'Runnable',
    _ => filter,
  };
}