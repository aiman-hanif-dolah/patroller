// Project-agnostic Patrol HTML report models.

enum ScenarioStatus {
  passed,
  failed,
  skipped,
  unknown;

  String get label => switch (this) {
        ScenarioStatus.passed => 'PASSED',
        ScenarioStatus.failed => 'FAILED',
        ScenarioStatus.skipped => 'SKIPPED',
        ScenarioStatus.unknown => 'UNKNOWN',
      };

  static ScenarioStatus fromLogToken(String raw) {
    final t = raw.trim().toUpperCase();
    if (t == 'PASSED' || t == 'PASS' || t == 'SUCCESS') {
      return ScenarioStatus.passed;
    }
    if (t == 'FAILED' || t == 'FAIL' || t == 'FAILURE') {
      return ScenarioStatus.failed;
    }
    if (t == 'SKIPPED' || t == 'SKIP') return ScenarioStatus.skipped;
    return ScenarioStatus.unknown;
  }
}

class ScenarioResult {
  const ScenarioResult({
    required this.name,
    required this.status,
    this.suiteOrTarget,
    this.sourceLog,
    this.durationHint,
  });

  final String name;
  final ScenarioStatus status;
  final String? suiteOrTarget;
  final String? sourceLog;
  final String? durationHint;

  bool get isPassed => status == ScenarioStatus.passed;
  bool get isFailed => status == ScenarioStatus.failed;
}

class LeafFileResult {
  const LeafFileResult({
    required this.relativePath,
    required this.area,
    required this.scenarios,
    this.declaredNames = const [],
  });

  final String relativePath;
  final String area;
  final List<ScenarioResult> scenarios;
  final List<String> declaredNames;

  int get passedCount =>
      scenarios.where((s) => s.status == ScenarioStatus.passed).length;
  int get failedCount =>
      scenarios.where((s) => s.status == ScenarioStatus.failed).length;

  String get rollupStatus {
    if (scenarios.isEmpty) return 'Not run';
    if (failedCount > 0) return 'Failed';
    if (passedCount > 0) return 'Passed';
    return 'Not run';
  }
}

class TargetResult {
  const TargetResult({
    required this.label,
    required this.passed,
    required this.failed,
    this.total,
    this.sourceLog,
    this.targetFile,
    this.exitCode,
    this.runStatus,
  });

  final String label;
  final int passed;
  final int failed;
  final int? total;
  final String? sourceLog;
  final String? targetFile;
  final int? exitCode;
  final String? runStatus;

  int get resolvedTotal => total ?? (passed + failed);
  bool get ok => failed == 0 && passed > 0;
}

class BatchReport {
  const BatchReport({
    required this.projectName,
    required this.projectPath,
    required this.generatedAt,
    required this.targets,
    required this.leaves,
    required this.scenarios,
    this.device,
    this.runMode,
    this.queueLabel,
    this.queueId,
    this.extraMeta = const {},
  });

  final String projectName;
  final String projectPath;
  final DateTime generatedAt;
  final List<TargetResult> targets;
  final List<LeafFileResult> leaves;
  final List<ScenarioResult> scenarios;
  final String? device;
  final String? runMode;
  final String? queueLabel;
  final String? queueId;
  final Map<String, String> extraMeta;

  int get scenarioPassed =>
      scenarios.where((s) => s.status == ScenarioStatus.passed).length;
  int get scenarioFailed =>
      scenarios.where((s) => s.status == ScenarioStatus.failed).length;
  int get scenarioTotal => scenarios.length;

  int get leafPassed => leaves.where((l) => l.rollupStatus == 'Passed').length;
  int get leafFailed => leaves.where((l) => l.rollupStatus == 'Failed').length;
  int get leafNotRun => leaves.where((l) => l.rollupStatus == 'Not run').length;

  int get targetPassedSum => targets.fold(0, (a, t) => a + t.passed);
  int get targetFailedSum => targets.fold(0, (a, t) => a + t.failed);

  double get passRate {
    final total = scenarioTotal > 0
        ? scenarioTotal
        : (targetPassedSum + targetFailedSum);
    if (total == 0) return 0;
    final passed = scenarioTotal > 0 ? scenarioPassed : targetPassedSum;
    return passed / total * 100;
  }
}
