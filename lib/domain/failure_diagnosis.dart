/// Maps common Patrol / tool stderr patterns to short, actionable guidance.
class FailureDiagnosis {
  const FailureDiagnosis({
    required this.title,
    required this.summary,
    required this.likelyFix,
    this.copyCommand,
    this.category = FailureCategory.unknown,
  });

  final String title;
  final String summary;
  final String likelyFix;
  final String? copyCommand;
  final FailureCategory category;

  String get bannerText => '$title: $summary';

  String get fullText {
    final buf = StringBuffer()
      ..writeln(title)
      ..writeln(summary)
      ..writeln('Likely fix: $likelyFix');
    if (copyCommand != null && copyCommand!.isNotEmpty) {
      buf.writeln('Command: $copyCommand');
    }
    return buf.toString().trim();
  }
}

enum FailureCategory {
  tooling,
  projectSetup,
  device,
  assertion,
  build,
  unknown,
}

/// Best-effort diagnosis from combined run logs / stderr.
FailureDiagnosis? diagnosePatrolFailure(String raw) {
  if (raw.trim().isEmpty) return null;
  final text = raw.toLowerCase();
  final stripped = raw
      .replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '')
      .replaceAll(RegExp(r'\[stdout\]|\[stderr\]'), '');

  // Tooling / CLI
  if (text.contains('patrol command was not found') ||
      text.contains('command not found: patrol') ||
      (text.contains('patrol') && text.contains('not found'))) {
    return const FailureDiagnosis(
      title: 'Patrol CLI missing',
      summary: 'The patrol command is not available on PATH.',
      likelyFix: 'Install Patrol CLI, then re-open Patroller.',
      copyCommand: 'dart pub global activate patrol_cli',
      category: FailureCategory.tooling,
    );
  }
  if (text.contains('flutter') &&
      (text.contains('not found') || text.contains('unable to find'))) {
    return const FailureDiagnosis(
      title: 'Flutter CLI missing',
      summary: 'Flutter is not available on PATH (or Settings path is wrong).',
      likelyFix:
          'Install Flutter or set the Flutter path in Patroller Settings (FVM users: point at the FVM flutter binary).',
      copyCommand: 'flutter --version',
      category: FailureCategory.tooling,
    );
  }

  // Native project setup
  if (text.contains('xcodebuild exited with code 70') ||
      (text.contains('total: 0') && text.contains('xcodebuild'))) {
    return const FailureDiagnosis(
      title: 'iOS native test host missing',
      summary:
          'xcodebuild finished with 0 tests (code 70) - usually no RunnerUITests target.',
      likelyFix:
          'Add iOS RunnerUITests + PATROL_INTEGRATION_TEST_IOS_RUNNER, then pod install. See Patrol iOS setup docs.',
      copyCommand: 'patrol doctor',
      category: FailureCategory.projectSetup,
    );
  }
  if (text.contains('mainactivitytest') ||
      text.contains('patroljunitrunner') ||
      (text.contains('instrumentation') && text.contains('not found'))) {
    return const FailureDiagnosis(
      title: 'Android instrumentation missing',
      summary: 'Android Patrol runner / MainActivityTest may not be wired.',
      likelyFix:
          'Add PatrolJUnitRunner + MainActivityTest under androidTest. See Patrol Android setup docs.',
      category: FailureCategory.projectSetup,
    );
  }

  // Device
  if (text.contains('no devices found') ||
      text.contains('no supported devices') ||
      text.contains('device not found')) {
    return const FailureDiagnosis(
      title: 'No device available',
      summary: 'Patrol could not use a connected/booted device.',
      likelyFix:
          'Boot an iOS Simulator (primary run target in Patroller), then select it in the device picker.',
      copyCommand: 'xcrun simctl list devices booted',
      category: FailureCategory.device,
    );
  }
  if (text.contains('only ios simulator') ||
      text.contains('select an ios simulator')) {
    return const FailureDiagnosis(
      title: 'iOS Simulator required',
      summary: 'Patroller runs are currently limited to iOS Simulator.',
      likelyFix: 'Select a booted iOS Simulator in the device picker.',
      category: FailureCategory.device,
    );
  }

  // Assertion failures (test logic)
  if (text.contains('testfailure') ||
      (text.contains('expected:') && text.contains('actual:')) ||
      text.contains('exception caught by flutter test framework')) {
    final expected = RegExp(
      r"Expected:\s*'([^']*)'",
      caseSensitive: false,
    ).firstMatch(stripped);
    final actual = RegExp(
      r"Actual:\s*'([^']*)'",
      caseSensitive: false,
    ).firstMatch(stripped);
    final detail = (expected != null && actual != null)
        ? "Expected '${expected.group(1)}' but got '${actual.group(1)}'."
        : 'A test assertion failed while the app was running.';
    return FailureDiagnosis(
      title: 'Test assertion failed',
      summary: detail,
      likelyFix:
          'Tooling and native setup are fine - fix the expectation or app behavior in the failing patrol test.',
      category: FailureCategory.assertion,
    );
  }

  // Build / xcode
  if (text.contains('xcodebuild exited with code 65') ||
      text.contains('** test failed **') ||
      text.contains('testing failed')) {
    // Prefer assertion if both present
    if (text.contains('expected:') || text.contains('testfailure')) {
      return diagnosePatrolFailure(
        stripped.replaceAll('xcodebuild exited with code 65', ''),
      );
    }
    return const FailureDiagnosis(
      title: 'iOS test execution failed',
      summary: 'xcodebuild exited with code 65 while running Patrol tests.',
      likelyFix:
          'Scroll logs for the first red EXCEPTION / TestFailure. If no assertion, check signing, pods, and RunnerUITests.',
      category: FailureCategory.build,
    );
  }
  if ((text.contains('pod install') && text.contains('error')) ||
      text.contains('cocoapods')) {
    return const FailureDiagnosis(
      title: 'CocoaPods issue',
      summary: 'iOS pods may be out of sync with the Patrol plugin.',
      likelyFix: 'Run pod install in the ios folder of the Flutter app under test.',
      copyCommand: 'cd ios && pod install && cd ..',
      category: FailureCategory.projectSetup,
    );
  }

  // Compatibility
  if (text.contains('compatibility table') ||
      text.contains('update available')) {
    // Soft signal only when paired with a real failure later
  }

  return null;
}

/// Prefer the last meaningful diagnosis when scanning multi-file Test All logs.
FailureDiagnosis? diagnoseFromLogChunks(Iterable<String> chunks) {
  FailureDiagnosis? last;
  for (final chunk in chunks) {
    final d = diagnosePatrolFailure(chunk);
    if (d != null) last = d;
  }
  return last;
}
