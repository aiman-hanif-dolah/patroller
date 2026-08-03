import 'dart:convert';
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

  bool get isFlutterSdk =>
      source == 'sdk' &&
      (constraint == 'flutter' ||
          constraint.contains('sdk: flutter') ||
          constraint.trim() == 'sdk:flutter');

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

  /// Start may proceed when failures are auto-repairable by prepare, or are
  /// deferred checks (dirty git override / selected simulator) handled later.
  bool get canStartPrepare {
    if (checks.any((check) => check.id == 'project' && !check.ok)) {
      return false;
    }
    return failures.every(
      (check) =>
          check.repairable || check.id == 'git' || check.id == 'device',
    );
  }

  List<String> get effectiveWriteLocations {
    final list = [...allowedWriteLocations];
    if (entrypoint != null && !list.contains(entrypoint)) {
      list.add(entrypoint!);
    }
    return list;
  }

  /// Re-evaluates the deferred `device` check from the live runner selection
  /// without re-running the full project inspect.
  RoutineReadinessReport withSelectedDevice(String? device) {
    final deviceOk =
        Platform.isMacOS && device != null && device.trim().isNotEmpty;
    final checks = this.checks
        .map(
          (check) => check.id == 'device'
              ? RoutineCheck(
                  id: check.id,
                  label: check.label,
                  ok: deviceOk,
                  detail: deviceOk
                      ? device!.trim()
                      : 'Boot and select an iOS Simulator (required to run; package setup can still proceed)',
                  repairable: check.repairable,
                  fixCommand: check.fixCommand,
                )
              : check,
        )
        .toList();
    final failures = checks.where((check) => !check.ok).toList();
    final hardFailures = failures.where(
      (check) =>
          !check.repairable && check.id != 'device' && check.id != 'git',
    );
    final blocked = hardFailures.isNotEmpty;
    return RoutineReadinessReport(
      status: failures.isEmpty
          ? RoutineReadiness.ready
          : blocked
          ? RoutineReadiness.blocked
          : RoutineReadiness.repairable,
      checks: checks,
      projectPath: projectPath,
      preview: preview,
      entrypoint: entrypoint,
      selectedDevice: deviceOk ? device!.trim() : null,
      allowedWriteLocations: allowedWriteLocations,
    );
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

/// Live-log line for a routine event (matches Agent card `[kind]` tags).
String formatRoutineEventLogLine(RoutineEvent event) {
  switch (event.kind) {
    case 'thinking':
    case 'thought':
      return '🧠 [AI Thinking] ${event.message}';
    case 'tool_call':
      return '🛠️ [Tool Call] ${event.message}';
    case 'tool_result':
      return '📥 [Tool Result] ${event.message}';
    case 'assistant':
      return '🤖 [AI Assistant] ${event.message}';
    case 'output':
      return '[routine] ${event.message}';
    default:
      return '[routine] [${event.kind}] ${event.message}';
  }
}

RoutineEvent parseOpenCodeOutputToRoutineEvent(String rawLine) {
  final trimmed = rawLine.trim();
  final now = DateTime.now();
  if (trimmed.isEmpty) {
    return RoutineEvent(time: now, kind: 'output', message: '');
  }

  String jsonCandidate = trimmed;
  if (jsonCandidate.startsWith('data: ')) {
    jsonCandidate = jsonCandidate.substring(6).trim();
  } else if (jsonCandidate.startsWith('data:')) {
    jsonCandidate = jsonCandidate.substring(5).trim();
  }

  if (jsonCandidate.startsWith('{') && jsonCandidate.endsWith('}')) {
    try {
      final Object? decoded = jsonDecode(jsonCandidate);
      if (decoded is Map<String, dynamic>) {
        final type = (decoded['type'] as String?)?.toLowerCase();

        // OpenCode SSE: message.part.updated / session.status / permission.*
        if (type == 'message.part.updated') {
          final props = decoded['properties'];
          if (props is Map && props['part'] is Map) {
            final part = (props['part'] as Map).cast<String, dynamic>();
            final partType = (part['type'] as String?)?.toLowerCase();
            if (partType == 'text') {
              final text = part['text'] ?? part['content'];
              if (text != null && text.toString().isNotEmpty) {
                return RoutineEvent(
                  time: now,
                  kind: 'assistant',
                  message: text.toString().trim(),
                );
              }
            }
            if (partType == 'reasoning' || partType == 'thinking') {
              final text = part['text'] ?? part['reasoning'] ?? part['thought'];
              if (text != null && text.toString().isNotEmpty) {
                return RoutineEvent(
                  time: now,
                  kind: 'thinking',
                  message: text.toString().trim(),
                );
              }
            }
            if (partType == 'tool' ||
                partType == 'tool_use' ||
                partType == 'tool_call') {
              final name = part['tool'] ?? part['name'] ?? 'tool';
              final state = part['state'] ?? part['input'] ?? '';
              return RoutineEvent(
                time: now,
                kind: 'tool_call',
                message: '$name $state',
              );
            }
          }
        }
        if (type == 'session.status') {
          final props = decoded['properties'];
          final status = props is Map ? props['status'] : null;
          final statusType =
              status is Map ? status['type']?.toString() : status?.toString();
          if (statusType != null && statusType.isNotEmpty) {
            return RoutineEvent(
              time: now,
              kind: 'output',
              message: 'OpenCode session status: $statusType',
            );
          }
        }
        if (type == 'permission.asked' || type == 'permission.v2.asked') {
          final props = decoded['properties'];
          final permission = props is Map
              ? (props['permission'] ?? props['action'] ?? 'permission')
              : 'permission';
          return RoutineEvent(
            time: now,
            kind: 'permission',
            message: 'OpenCode permission requested: $permission',
          );
        }

        // 1. Thinking / Reasoning / Thoughts
        if (type == 'thought' || type == 'thinking' || type == 'reasoning') {
          final text = decoded['text'] ??
              decoded['thinking'] ??
              decoded['reasoning'] ??
              decoded['content'];
          if (text != null && text.toString().isNotEmpty) {
            return RoutineEvent(
              time: now,
              kind: 'thinking',
              message: text.toString().trim(),
            );
          }
        }

        // 2. Part objects
        if (type == 'part' && decoded['part'] is Map<String, dynamic>) {
          final part = decoded['part'] as Map<String, dynamic>;
          final partType = (part['type'] as String?)?.toLowerCase();
          if (partType == 'reasoning' || partType == 'thought') {
            final text = part['reasoning'] ?? part['text'] ?? part['thought'];
            if (text != null && text.toString().isNotEmpty) {
              return RoutineEvent(
                time: now,
                kind: 'thinking',
                message: text.toString().trim(),
              );
            }
          }
          if (partType == 'text') {
            final text = part['text'] ?? part['content'];
            if (text != null && text.toString().isNotEmpty) {
              return RoutineEvent(
                time: now,
                kind: 'assistant',
                message: text.toString().trim(),
              );
            }
          }
          if (partType == 'tool_use' || partType == 'tool_call') {
            final name = part['name'] ?? part['tool'] ?? 'tool';
            final input = part['input'] ?? part['parameters'] ?? part['args'] ?? '';
            return RoutineEvent(
              time: now,
              kind: 'tool_call',
              message: '$name $input',
            );
          }
        }

        // 3. Tool Calls
        if (type == 'tool_call' || type == 'tool_use' || type == 'call') {
          final name =
              decoded['name'] ?? decoded['tool'] ?? decoded['function'] ?? 'tool';
          final params =
              decoded['parameters'] ?? decoded['input'] ?? decoded['args'] ?? '';
          return RoutineEvent(
            time: now,
            kind: 'tool_call',
            message: '$name $params',
          );
        }

        // 4. Tool Results
        if (type == 'tool_result' || type == 'tool_response' || type == 'result') {
          final output =
              decoded['output'] ?? decoded['content'] ?? decoded['result'] ?? '';
          final text = output.toString().trim();
          final summary =
              text.length > 250 ? '${text.substring(0, 250)}…' : text;
          return RoutineEvent(
            time: now,
            kind: 'tool_result',
            message: summary,
          );
        }

        // 5. Assistant Messages
        if (type == 'message' ||
            type == 'assistant' ||
            type == 'text' ||
            type == 'delta') {
          final text = decoded['text'] ??
              decoded['content'] ??
              decoded['message'] ??
              (decoded['delta'] is Map ? decoded['delta']['text'] : null);
          if (text != null && text.toString().isNotEmpty) {
            return RoutineEvent(
              time: now,
              kind: 'assistant',
              message: text.toString().trim(),
            );
          }
        }

        // 6. Generic JSON fallback
        if (decoded.containsKey('message')) {
          return RoutineEvent(
            time: now,
            kind: 'output',
            message: decoded['message'].toString(),
          );
        }
      }
    } catch (_) {}
  }

  return RoutineEvent(time: now, kind: 'output', message: trimmed);
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
    required this.deviceId,
    this.customInstructions,
    this.maxMinutes = 90,
    this.maxIterations = 15,
    this.noProgressLimit = 3,
    this.allowDirtyWorktree = false,
  });

  final String projectPath;
  final String goal;
  final String model;
  /// Booted iOS Simulator id (UDID) or name for Patrol/Flutter `-d`.
  final String deviceId;
  final String? customInstructions;
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

