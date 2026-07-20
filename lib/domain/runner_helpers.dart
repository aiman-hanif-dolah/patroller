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

/// Empty-logs busy copy: Starting only while starting, Stopping while stopping.
String emptyLogsBusyMessage(RunLifecycle? lifecycle) {
  return switch (lifecycle) {
    RunLifecycle.starting => 'Starting...',
    RunLifecycle.stopping => 'Stopping...',
    _ => 'Running...',
  };
}

/// Whether Develop All should auto-start the next queued file after a run ends.
bool shouldAdvanceDevelopSuite({
  required bool userStopped,
  required RunMode completedMode,
  required bool queueNotEmpty,
}) {
  return !userStopped &&
      completedMode == RunMode.developSuite &&
      queueNotEmpty;
}

/// Sentinel for the Test Explorer "All flows" dropdown (null items are unreliable).
const kAllFlowsFilter = '';

bool isAllFlowsFilter(String flowFilter) => flowFilter == kAllFlowsFilter;

/// File IDs selected when the flow dropdown changes.
Set<String> selectedFileIdsForFlowFilter(
  List<TestFile> testFiles,
  String flowFilter,
) {
  if (isAllFlowsFilter(flowFilter)) {
    return testFiles.map((f) => f.absolutePath).toSet();
  }
  return testFiles
      .where((f) => f.folderPath.startsWith(flowFilter))
      .map((f) => f.absolutePath)
      .toSet();
}

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
  // Not booted is OK — runtime auto-boots via _ensureDevice.
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
  // Not booted is OK — runtime auto-boots via _ensureDevice.
  return null;
}

/// Files for Test All / Develop All: multi-select when set, else all runnable.
List<TestFile> filesForRunAll(
  List<TestFile> allFiles,
  Set<String> selectedFileIds,
) {
  final runnable = runnableTestFiles(allFiles);
  if (selectedFileIds.isEmpty) return runnable;
  final selected = runnable
      .where((f) => selectedFileIds.contains(f.absolutePath))
      .toList();
  return selected.isNotEmpty ? selected : runnable;
}

bool isRunnableTestFile(TestFile file) => file.detectedTestCount > 0;

bool isHelperTestFile(TestFile file) => file.detectedTestCount == 0;

List<TestFile> runnableTestFiles(List<TestFile> files) =>
    files.where(isRunnableTestFile).toList();

({String label, String value}) describeTestAllQueueBadge(int selectedCount) {
  if (selectedCount == 0) {
    return (label: 'Test All', value: 'All runnable');
  }
  return (
    label: 'Test All',
    value: '$selectedCount file${selectedCount == 1 ? '' : 's'} selected',
  );
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

/// Patrol develop prints this when the current test cycle finishes.
bool isAllTestsExecutedMessage(String text) {
  return text.toLowerCase().contains('all tests were executed');
}

/// Snackbar copy when a single-file run or develop cycle completes.
String? sessionCompletionSnackbarMessage({
  required RunMode runMode,
  required RunRecordStatus status,
  required bool allTestsExecutedSeen,
  bool developSuiteHasMore = false,
}) {
  if (developSuiteHasMore) return null;

  switch (runMode) {
    case RunMode.test:
      return switch (status) {
        RunRecordStatus.passed => 'Test finished — all tests passed',
        RunRecordStatus.failed || RunRecordStatus.error =>
          'Test finished — failed',
        _ => null,
      };
    case RunMode.develop:
      if (allTestsExecutedSeen || status == RunRecordStatus.passed) {
        return 'Develop session finished — all tests executed';
      }
      return null;
    case RunMode.developSuite:
      if (allTestsExecutedSeen || status == RunRecordStatus.passed) {
        return 'Develop All finished — all tests executed';
      }
      return null;
    case RunMode.fullSuite:
      return null;
  }
}