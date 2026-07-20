import 'report_models.dart';

/// Parses Patrol / xcodebuild integration-test logs into scenario results.
///
/// Project-agnostic: works for any Flutter app that runs via `patrol test`.
class PatrolLogParser {
  PatrolLogParser();

  /// CSI / OSC color and cursor codes from patrol_cli pretty output.
  static final _ansiEscape = RegExp(r'\x1B\[[0-9;?]*[ -/]*[@-~]');

  /// Strip ANSI so result lines match regardless of terminal styling.
  String stripAnsi(String input) => input.replaceAll(_ansiEscape, '');

  /// Verbose iOS runner line (myastro / suite style).
  static final _runDartTestResult = RegExp(
    r'runDartTest\("(?:suite\.[^"]+?\s+)?([^"]+)"\):\s*call finished,\s*test result:\s*(PASSED|FAILED|SKIPPED)',
    caseSensitive: false,
  );

  /// ✅/❌ name (/suite/foo_suite_test.dart) (12s)
  static final _emojiSuiteResult = RegExp(
    r'(✅|❌)\s+(.+?)\s+\(/suite/[^)]+\)(?:\s+\([^)]*\))?',
  );

  /// ✅/❌ name (/path/to/foo_test.dart) (0s)  — current patrol_cli summary style
  static final _emojiFileResult = RegExp(
    r'(✅|❌)\s+(.+?)\s+\(([^)]*_test\.dart)\)(?:\s+\([^)]*\))?',
  );

  /// Failure list under Test summary:
  ///   - app launches and native home press works (/smoke_test.dart)
  static final _summaryFailureLine = RegExp(
    r'^\s*-\s+(.+?)\s+\(([^)]*\.dart)\)\s*$',
    multiLine: true,
  );

  /// Prefer the *last* Test summary block (final rollup for that run).
  static final _testSummaryBlock = RegExp(
    r'Test summary:\s*[\r\n]+'
    r'(?:.*[\r\n]+)*?'
    r'✅\s*Successful:\s*(\d+)\s*[\r\n]+\s*'
    r'❌\s*Failed:\s*(\d+)',
    caseSensitive: false,
  );

  static final _successfulFailedLoose = RegExp(
    r'✅\s*Successful:\s*(\d+)\s*[\r\n]+\s*❌\s*Failed:\s*(\d+)',
  );

  static final _testExecute = RegExp(
    r'\*\*\s*TEST EXECUTE\s+(SUCCEEDED|FAILED)\s*\*\*',
    caseSensitive: false,
  );

  /// Lines that are step ticks, not scenario results (e.g. "✅   1. tap …").
  static final _stepTick = RegExp(r'^[✅❌]\s+\d+\.\s');

  /// Extract individual scenario pass/fail lines from a log blob.
  List<ScenarioResult> parseScenarios(
    String log, {
    String? suiteOrTarget,
    String? sourceLog,
  }) {
    if (log.isEmpty) return const [];
    log = stripAnsi(log);

    final byName = <String, ScenarioResult>{};

    void add(String name, ScenarioStatus status) {
      final cleaned = name.trim();
      if (cleaned.isEmpty) return;
      // Ignore step ticks mistaken as titles
      if (RegExp(r'^\d+\.\s').hasMatch(cleaned)) return;
      // Later FAILED overrides earlier PASSED for the same name
      final existing = byName[cleaned];
      if (existing != null &&
          existing.status == ScenarioStatus.failed &&
          status == ScenarioStatus.passed) {
        return;
      }
      byName[cleaned] = ScenarioResult(
        name: cleaned,
        status: status,
        suiteOrTarget: suiteOrTarget,
        sourceLog: sourceLog,
      );
    }

    for (final m in _runDartTestResult.allMatches(log)) {
      add(m.group(1)!, ScenarioStatus.fromLogToken(m.group(2)!));
    }

    for (final m in _emojiSuiteResult.allMatches(log)) {
      add(
        m.group(2)!,
        m.group(1) == '✅' ? ScenarioStatus.passed : ScenarioStatus.failed,
      );
    }

    for (final m in _emojiFileResult.allMatches(log)) {
      final lineStart = log.lastIndexOf('\n', m.start) + 1;
      final line = log.substring(lineStart, m.end);
      if (_stepTick.hasMatch(line.trimLeft())) continue;
      // Skip summary rollup lines like "✅ Successful: 5"
      final title = m.group(2)!.trim();
      if (title.toLowerCase().startsWith('successful:') ||
          title.toLowerCase().startsWith('failed:')) {
        continue;
      }
      add(
        title,
        m.group(1) == '✅' ? ScenarioStatus.passed : ScenarioStatus.failed,
      );
    }

    // Failure bullets under "Test summary" (when emoji result lines were truncated)
    for (final m in _summaryFailureLine.allMatches(log)) {
      add(m.group(1)!, ScenarioStatus.failed);
    }

    return byName.values.toList();
  }

  /// Parse suite-level Successful/Failed counts when present.
  /// Uses the **last** Test summary in the log (final rollup for this run only).
  ({int passed, int failed})? parseSuiteCounts(String log) {
    log = stripAnsi(log);
    final blocks = _testSummaryBlock.allMatches(log).toList();
    if (blocks.isNotEmpty) {
      final m = blocks.last;
      return (passed: int.parse(m.group(1)!), failed: int.parse(m.group(2)!));
    }
    final loose = _successfulFailedLoose.allMatches(log).toList();
    if (loose.isEmpty) return null;
    final m = loose.last;
    return (passed: int.parse(m.group(1)!), failed: int.parse(m.group(2)!));
  }

  bool? parseExecuteSucceeded(String log) {
    log = stripAnsi(log);
    final m = _testExecute.allMatches(log).toList();
    if (m.isEmpty) return null;
    return m.last.group(1)!.toUpperCase() == 'SUCCEEDED';
  }
}
