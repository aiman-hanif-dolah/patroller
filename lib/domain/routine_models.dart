import 'dart:io';

enum RoutineReadiness { ready, repairable, blocked }

enum RoutineStatus {
  idle,
  checking,
  awaitingApproval,
  running,
  stopping,
  completed,
  needsAttention,
}

class ProjectDependency {
  const ProjectDependency({
    required this.name,
    required this.section,
    required this.constraint,
    this.source,
  });

  final String name;
  final String section;
  final String constraint;
  final String? source;

  bool get isDev => section == 'dev_dependencies';

  String get removeCommand => 'flutter pub remove $name';
  List<String> get affectedFiles => const ['pubspec.yaml', 'pubspec.lock'];
}

class OpenCodeModel {
  const OpenCodeModel({
    required this.id,
    required this.provider,
    required this.name,
    required this.inputCost,
    required this.outputCost,
  });

  final String id;
  final String provider;
  final String name;
  final double? inputCost;
  final double? outputCost;

  bool get verifiedFree => inputCost == 0 && outputCost == 0;
}

class RoutineCheck {
  const RoutineCheck({
    required this.id,
    required this.label,
    required this.ok,
    required this.detail,
    this.repairable = false,
    this.fixCommand,
  });

  final String id;
  final String label;
  final bool ok;
  final String detail;
  final bool repairable;
  final String? fixCommand;
}

class RoutineReadinessReport {
  const RoutineReadinessReport({
    required this.status,
    required this.checks,
    required this.projectPath,
    required this.preview,
    this.entrypoint,
    this.selectedDevice,
    this.allowedWriteLocations = const [
      'patrol_test/**',
      'pubspec.yaml',
      'pubspec.lock',
    ],
  });

  final RoutineReadiness status;
  final List<RoutineCheck> checks;
  final String projectPath;
  final List<String> preview;
  final String? entrypoint;
  final String? selectedDevice;
  final List<String> allowedWriteLocations;

  bool get ok =>
      status == RoutineReadiness.ready || status == RoutineReadiness.repairable;

  List<RoutineCheck> get failures =>
      checks.where((check) => !check.ok).toList();

  List<String> get effectiveWriteLocations {
    final list = [...allowedWriteLocations];
    if (entrypoint != null && !list.contains(entrypoint)) {
      list.add(entrypoint!);
    }
    return list;
  }
}

class RoutineEvent {
  const RoutineEvent({
    required this.time,
    required this.kind,
    required this.message,
  });

  final DateTime time;
  final String kind;
  final String message;
}

class RoutineResult {
  const RoutineResult({
    required this.status,
    required this.message,
    required this.startedAt,
    required this.finishedAt,
    this.passedTests = const [],
    this.failedTests = const [],
    this.changedFiles = const [],
    this.reportPath,
    this.baselinePassed = false,
    this.finalSweepPassed = false,
    this.stoppingReason,
  });

  final RoutineStatus status;
  final String message;
  final DateTime startedAt;
  final DateTime finishedAt;
  final List<String> passedTests;
  final List<String> failedTests;
  final List<String> changedFiles;
  final String? reportPath;
  final bool baselinePassed;
  final bool finalSweepPassed;
  final String? stoppingReason;
}

class PermissionRequest {
  const PermissionRequest({
    required this.id,
    required this.tool,
    required this.description,
    this.params = const {},
  });

  final String id;
  final String tool;
  final String description;
  final Map<String, dynamic> params;
}

class RoutinePlan {
  const RoutinePlan({
    required this.projectPath,
    required this.goal,
    required this.model,
    this.maxMinutes = 90,
    this.maxIterations = 15,
    this.noProgressLimit = 3,
    this.allowDirtyWorktree = false,
  });

  final String projectPath;
  final String goal;
  final String model;
  final int maxMinutes;
  final int maxIterations;
  final int noProgressLimit;
  final bool allowDirtyWorktree;

  Duration get timeout => Duration(minutes: maxMinutes);
}

String routineStatusLabel(RoutineStatus status) => switch (status) {
  RoutineStatus.idle => 'Idle',
  RoutineStatus.checking => 'Checking readiness…',
  RoutineStatus.awaitingApproval => 'Approval required',
  RoutineStatus.running => 'Routine running',
  RoutineStatus.stopping => 'Stopping…',
  RoutineStatus.completed => 'Completed',
  RoutineStatus.needsAttention => 'Needs attention',
};

String platformRoutineNote() => Platform.isMacOS
    ? 'macOS / iOS Simulator routine'
    : 'macOS / iOS Simulator routine is required for execution';

