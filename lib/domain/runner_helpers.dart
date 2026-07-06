import 'log_classification.dart';
import '../models/models.dart';

bool isActiveLifecycle(RunLifecycle? value) {
  return value == RunLifecycle.starting ||
      value == RunLifecycle.running ||
      value == RunLifecycle.stopping;
}

bool isSessionBusy(bool isRunning, RunRecord? currentRun) {
  if (isRunning) return true;
  return isActiveLifecycle(currentRun?.lifecycle);
}

RunLifecycle? resolveLifecycle(RunRecord? run) => run?.lifecycle;

bool isSelectableDevice(DeviceInfo device) {
  return device.type == DeviceType.iosSimulator;
}

String? getDeviceUnavailableReason(DeviceInfo device) {
  if (device.type != DeviceType.iosSimulator) {
    return 'Only iOS Simulator is supported';
  }
  return null;
}

DeviceInfo? pickDefaultSelectableDevice(List<DeviceInfo> devices) {
  final booted = devices.where(
    (d) => isSelectableDevice(d) && d.state == DeviceState.booted,
  );
  if (booted.isNotEmpty) return booted.first;
  final selectable = devices.where(isSelectableDevice);
  if (selectable.isNotEmpty) return selectable.first;
  return null;
}

String? runnerControlsDisabledReason(bool isRunning, RunRecord? currentRun) {
  if (!isSessionBusy(isRunning, currentRun)) return null;
  final mode = currentRun?.runMode;
  if (mode == RunMode.develop || mode == RunMode.developSuite) {
    return 'Stop the active Develop session first';
  }
  if (isRunning || isActiveLifecycle(currentRun?.lifecycle)) {
    return 'A run is already in progress';
  }
  return null;
}

String? getRunDisabledReason({
  required bool hasProject,
  required bool hasSelectedFile,
  required bool isRunning,
  required DeviceInfo? selectedDevice,
  required RunRecord? currentRun,
}) {
  if (!hasProject) return 'Open a Flutter project first';
  final sessionBlock = runnerControlsDisabledReason(isRunning, currentRun);
  if (sessionBlock != null) return sessionBlock;
  if (!hasSelectedFile) return 'Choose a test file first';
  if (selectedDevice == null) return 'Select an iOS Simulator to run tests';
  if (!isSelectableDevice(selectedDevice)) {
    return 'Only iOS Simulator is supported';
  }
  if (selectedDevice.state != DeviceState.booted) {
    return 'Boot the simulator before running tests';
  }
  return null;
}

bool isDevelopSession(RunRecord? run) {
  return run?.runMode == RunMode.develop ||
      run?.runMode == RunMode.developSuite;
}

String? hotRestartDisabledReason({
  required bool isRunning,
  required RunRecord? currentRun,
}) {
  if (currentRun == null ||
      !isDevelopSession(currentRun) ||
      !isRunning) {
    return 'No active develop session';
  }
  final lifecycle = resolveLifecycle(currentRun);
  if (lifecycle == RunLifecycle.starting) {
    return 'Waiting for session to start';
  }
  if (lifecycle == RunLifecycle.stopping) {
    return 'Stopping...';
  }
  return null;
}

String? getQueueRunDisabledReason({
  required bool hasProject,
  required bool hasTestFiles,
  required bool isRunning,
  required DeviceInfo? selectedDevice,
  required RunRecord? currentRun,
}) {
  if (!hasProject) return 'Open a Flutter project first';
  final sessionBlock = runnerControlsDisabledReason(isRunning, currentRun);
  if (sessionBlock != null) return sessionBlock;
  if (!hasTestFiles) return 'No test files discovered yet';
  if (selectedDevice == null) return 'Select an iOS Simulator to run tests';
  if (!isSelectableDevice(selectedDevice)) {
    return 'Only iOS Simulator is supported';
  }
  if (selectedDevice.state != DeviceState.booted) {
    return 'Boot the simulator before running tests';
  }
  return null;
}

bool isRunnableTestFile(TestFile file) => file.detectedTestCount > 0;

bool isHelperTestFile(TestFile file) => file.detectedTestCount == 0;

List<TestFile> runnableTestFiles(List<TestFile> files) =>
    files.where(isRunnableTestFile).toList();

({String label, String value}) describeTestAllQueueBadge(int selectedCount) {
  if (selectedCount == 0) {
    return (label: 'Test All', value: 'All runnable');
  }
  return (label: 'Test All', value: '$selectedCount selected');
}

String formatTestAllSelectionBanner(int selectedCount) {
  if (selectedCount == 0) return 'All runnable files';
  return '$selectedCount file${selectedCount == 1 ? '' : 's'} selected for Test All';
}

String formatTestExplorerHeader(
  int totalFiles,
  int totalTests,
  int filteredFiles,
  bool filterActive, {
  int? runnableFiles,
  int? runnableTests,
}) {
  final runnableFileCount = runnableFiles ?? totalFiles;
  final runnableTestCount = runnableTests ?? totalTests;
  if (filterActive) {
    return '$filteredFiles / $runnableFileCount runnable files · $runnableTestCount tests';
  }
  if (runnableFileCount == totalFiles) {
    return '$totalFiles files · $runnableTestCount tests';
  }
  return '$runnableFileCount runnable / $totalFiles files · $runnableTestCount tests';
}

String middleTruncate(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  final keep = (maxLength - 1) ~/ 2;
  return '${text.substring(0, keep)}…${text.substring(text.length - keep)}';
}

TestStatus runRecordStatusToTestStatus(RunRecordStatus status) {
  return switch (status) {
    RunRecordStatus.passed => TestStatus.passed,
    RunRecordStatus.failed || RunRecordStatus.error => TestStatus.failed,
    RunRecordStatus.cancelled || RunRecordStatus.skipped => TestStatus.cancelled,
    RunRecordStatus.running => TestStatus.running,
    RunRecordStatus.queued => TestStatus.queued,
  };
}

String formatLogEventForExport(LogEvent log) {
  final time = formatLogTimestamp(log.timestamp);
  final label = logCategoryStyles[classifyLog(log)]!.label;
  return '$time | $label | ${log.text}';
}

String formatRunLogsForExport({
  required List<LogEvent> logs,
  String? combinedLog,
  String? stderrLog,
}) {
  if (logs.isNotEmpty) {
    return logs.map(formatLogEventForExport).join('\n');
  }
  final combined = combinedLog?.trim() ?? '';
  final stderr = stderrLog?.trim() ?? '';
  if (combined.isNotEmpty && stderr.isNotEmpty) {
    return '$combined\n--- stderr ---\n$stderr';
  }
  return combined.isNotEmpty ? combined : stderr;
}

bool isFailedRunStatus(RunRecordStatus status) {
  return status == RunRecordStatus.failed || status == RunRecordStatus.error;
}