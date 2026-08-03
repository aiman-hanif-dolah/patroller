import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/routine_models.dart';
import 'app_paths.dart';
import 'cli_env.dart';
import 'mcp_service.dart';
import 'opencode_service.dart';
import 'project_tooling_service.dart';

class RoutineService {
  RoutineService({
    ProjectToolingService? projectTooling,
    OpenCodeService? openCode,
    McpService? mcp,
  })  : projectTooling = projectTooling ?? ProjectToolingService(),
        openCode = openCode ?? OpenCodeService(),
        mcp = mcp ?? McpService();

  final ProjectToolingService projectTooling;
  final OpenCodeService openCode;
  final McpService mcp;

  Future<RoutineReadinessReport> inspect({
    required String projectPath,
    String? selectedDevice,
  }) async {
    final report = await projectTooling.inspect(
      projectPath: projectPath,
      selectedDevice: selectedDevice,
    );
    final checks = [...report.checks];
    final openCodeStatus = await openCode.detect();
    final openCodeInstallCmd = await openCode.getInstallCommand();
    checks.add(
      RoutineCheck(
        id: 'opencode',
        label: 'OpenCode CLI',
        ok: openCodeStatus.available,
        detail: openCodeStatus.available
            ? (openCodeStatus.version ?? 'Available')
            : 'OpenCode is not available on PATH',
        repairable: Platform.isMacOS && openCodeInstallCmd != null,
        fixCommand: openCodeStatus.available
            ? null
            : openCodeInstallCmd,
      ),
    );
    final dart = await _probe('dart', const ['--version']);
    checks.add(
      RoutineCheck(
        id: 'dart',
        label: 'Dart CLI',
        ok: dart,
        detail: dart ? 'Dart is available' : 'Dart is required for MCP servers',
      ),
    );
    final patrol = await _probe('patrol', const ['--version']);
    checks.add(
      RoutineCheck(
        id: 'patrol_cli',
        label: 'Patrol CLI',
        ok: patrol,
        detail: patrol
            ? 'Patrol CLI is available'
            : 'Install patrol_cli before running tests',
        repairable: true,
        fixCommand: patrol ? null : 'dart pub global activate patrol_cli',
      ),
    );
    final failed = checks.where((check) => !check.ok).toList();
    final hardFailures = failed.where(
      (check) =>
          !check.repairable && check.id != 'device' && check.id != 'git',
    );
    final blocked = hardFailures.isNotEmpty;
    return RoutineReadinessReport(
      status: failed.isEmpty
          ? RoutineReadiness.ready
          : blocked
              ? RoutineReadiness.blocked
              : RoutineReadiness.repairable,
      checks: checks,
      projectPath: report.projectPath,
      entrypoint: report.entrypoint,
      selectedDevice: selectedDevice,
      preview: [
        ...report.preview,
        ...failed
            .where((check) => check.fixCommand != null)
            .map((check) => check.fixCommand!),
      ],
    );
  }

  Future<List<ProjectCommandResult>> prepare(
    RoutineReadinessReport report,
  ) async {
    final results = <ProjectCommandResult>[];
    if (report.checks.any((check) => check.id == 'patrol_cli' && !check.ok)) {
      results.add(await projectTooling.installPatrolCli());
    }
    if (report.checks.any((check) => check.id == 'patrol_host_wiring' && !check.ok)) {
      results.add(await projectTooling.setupNativePatrolHost(report.projectPath));
    }
    final dependencies = await projectTooling.listDependencies(
      report.projectPath,
    );
    ProjectDependency? dependencyNamed(String name) {
      for (final dependency in dependencies) {
        if (dependency.name == name) return dependency;
      }
      return null;
    }

    bool has(String name) => dependencyNamed(name) != null;
    if (!has('patrol')) {
      results.add(
        await projectTooling.addDependency(
          report.projectPath,
          'patrol',
          dev: true,
        ),
      );
    }
    final integration = dependencyNamed('integration_test');
    if (integration == null || !integration.isFlutterSdk) {
      results.add(
        await projectTooling.ensureFlutterSdkDependency(
          report.projectPath,
          'integration_test',
          dev: true,
        ),
      );
    }
    if (!has('patrol_mcp')) {
      results.add(
        await projectTooling.addDependency(
          report.projectPath,
          'patrol_mcp',
          dev: true,
        ),
      );
    }
    if (!has('marionette_flutter')) {
      results.add(
        await projectTooling.addDependency(
          report.projectPath,
          'marionette_flutter',
        ),
      );
    }
    if (report.entrypoint != null) {
      await applyMarionetteBinding(report.projectPath, report.entrypoint!);
    }
    results.add(await projectTooling.pubGet(report.projectPath));
    return results;
  }

  Future<void> applyMarionetteBinding(
    String projectPath,
    String entrypoint,
  ) async {
    final file = File(p.join(projectPath, entrypoint));
    if (!file.existsSync()) return;
    var content = await file.readAsString();
    if (content.contains('MarionetteBinding')) return;
    if (!content.contains('package:marionette_flutter/')) {
      content = "import 'package:flutter/foundation.dart';\n"
          "import 'package:marionette_flutter/marionette_flutter.dart';\n$content";
    }
    const replacement = '''if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }''';
    if (content.contains('WidgetsFlutterBinding.ensureInitialized();')) {
      content = content.replaceFirst(
        'WidgetsFlutterBinding.ensureInitialized();',
        replacement,
      );
    } else {
      final main = RegExp(r'void main\s*\([^)]*\)\s*\{');
      final match = main.firstMatch(content);
      if (match == null) return;
      content = content.replaceRange(
        match.end,
        match.end,
        '\n  if (kDebugMode) MarionetteBinding.ensureInitialized();',
      );
    }
    await file.writeAsString(content);
  }

  Future<String> run({
    required RoutinePlan plan,
    required void Function(RoutineEvent event) onEvent,
    void Function(PermissionRequest request)? onPermissionRequest,
  }) async {
    final device = plan.deviceId.trim();
    if (device.isEmpty) {
      throw StateError(
        'Boot and select an iOS Simulator before running the routine.',
      );
    }

    final stamp = DateTime.now().millisecondsSinceEpoch.toString();
    final dataDir = patrolStudioUserDataDirSync();
    final routineDir = Directory(p.join(dataDir.path, 'routines', stamp));
    await routineDir.create(recursive: true);
    final marionette = await mcp.resolveMarionetteMcp();
    final marionetteEnv = <String, String>{};
    Process? debugAppProcess;
    final events = <RoutineEvent>[];
    void emit(RoutineEvent event) {
      events.add(event);
      onEvent(event);
    }

    try {
      emit(
        RoutineEvent(
          time: DateTime.now(),
          kind: 'started',
          message: 'OpenCode routine started with ${plan.model} on $device',
        ),
      );

      // Baseline before Marionette flutter run so both do not fight the same simulator.
      final baseline = await projectTooling.runPatrolSweep(
        plan.projectPath,
        device: device,
      );
      emit(
        RoutineEvent(
          time: DateTime.now(),
          kind: 'baseline',
          message: baseline.ok
              ? 'Baseline Patrol sweep passed'
              : 'Baseline Patrol sweep found failures: ${baseline.output}',
        ),
      );

      try {
        final flutterExec = resolveExecutable('flutter');
        final entrypoint = projectTooling.findEntrypoint(plan.projectPath) ?? 'lib/main.dart';
        debugAppProcess = await Process.start(
          flutterExec,
          ['run', '-d', device, '--debug', '-t', entrypoint],
          workingDirectory: plan.projectPath,
          environment: developerToolEnv(),
        );
        final vmCompleter = Completer<String?>();
        debugAppProcess.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          final match = RegExp(r'(http|ws)://(127\.0\.0\.1|localhost|\[::1\]):\d+/[A-Za-z0-9_=-]*/?ws?').firstMatch(line);
          if (match != null && !vmCompleter.isCompleted) {
            vmCompleter.complete(match.group(0));
          }
        });
        final vmUri = await vmCompleter.future.timeout(
          const Duration(seconds: 12),
          onTimeout: () => null,
        );
        if (vmUri != null) {
          marionetteEnv['MARIONETTE_VM_SERVICE_URI'] = vmUri;
          marionetteEnv['VM_SERVICE_URL'] = vmUri;
          emit(
            RoutineEvent(
              time: DateTime.now(),
              kind: 'debug_session',
              message: 'Connected Marionette instrumentation to Flutter VM Service at $vmUri',
            ),
          );
        } else {
          emit(
            RoutineEvent(
              time: DateTime.now(),
              kind: 'debug_session',
              message: 'Automated Flutter debug session launched on $device; Marionette will connect upon VM Service readiness',
            ),
          );
        }
      } catch (e) {
        emit(
          RoutineEvent(
            time: DateTime.now(),
            kind: 'debug_session',
            message: 'Marionette auto-launch note: $e',
          ),
        );
      }

      final configPath = await openCode.writeIsolatedConfig(
        directory: routineDir.path,
        projectPath: plan.projectPath,
        patrolCommand: resolveExecutable('dart'),
        patrolArgs: const ['run', 'patrol_mcp'],
        patrolEnvironment: {
          'PROJECT_ROOT': plan.projectPath,
          'PATROL_FLAGS': '-d $device',
          'SHOW_TERMINAL': 'false',
        },
        marionetteCommand: marionette.command,
        marionetteArgs: const [],
        marionetteEnvironment: marionetteEnv,
        model: plan.model,
      );
      final prompt = '''You are running a bounded Patroller routine.
Project: ${plan.projectPath}
Target device: $device
Goal: ${plan.goal}
Budget: ${plan.maxMinutes} minutes, ${plan.maxIterations} iterations, stop after ${plan.noProgressLimit} repeated no-progress iterations.
Use Patrol MCP for tests and Marionette MCP for live Flutter exploration.
Always target device "$device" (pass it to Patrol MCP run / patrol test -d). Do not use another device.
Read the project rules first. Only edit patrol_test/** and approved dependency/debug bridge files. Never commit, push, delete unrelated files, or change native host files.
Explore, repair outdated tests, create meaningful non-duplicate tests, and validate every change. Finish with a concise report of changed files, passing tests, failures, and blockers.''';

      final exitCode = await openCode
          .runRoutine(
        projectPath: plan.projectPath,
        model: plan.model,
        prompt: prompt,
        configPath: configPath,
        onOutput: (line) => emit(parseOpenCodeOutputToRoutineEvent(line)),
        onPermissionRequest: onPermissionRequest,
      )
          .timeout(
        plan.timeout,
        onTimeout: () async {
          await openCode.stopRoutine();
          return -1;
        },
      );

      // Release the simulator before the final Patrol sweep.
      debugAppProcess?.kill(ProcessSignal.sigterm);
      debugAppProcess = null;

      final finalSweep = await projectTooling.runPatrolSweep(
        plan.projectPath,
        device: device,
      );
      emit(
        RoutineEvent(
          time: DateTime.now(),
          kind: exitCode == 0 && finalSweep.ok ? 'completed' : 'failed',
          message: exitCode == 0 && finalSweep.ok
              ? 'OpenCode finished and the final Patrol sweep passed'
              : 'Routine verification failed: ${finalSweep.output}',
        ),
      );
      final reportPath = p.join(routineDir.path, 'routine-report.json');
      await File(reportPath).writeAsString(
        JsonEncoder.withIndent('  ').convert({
          'projectPath': plan.projectPath,
          'goal': plan.goal,
          'model': plan.model,
          'deviceId': device,
          'exitCode': exitCode,
          'baselinePassed': baseline.ok,
          'finalSweepPassed': finalSweep.ok,
          'startedAt':
              events.isEmpty ? null : events.first.time.toIso8601String(),
          'finishedAt': DateTime.now().toIso8601String(),
          'events': events
              .map(
                (event) => {
                  'time': event.time.toIso8601String(),
                  'kind': event.kind,
                  'message': event.message,
                },
              )
              .toList(),
        }),
      );
      return reportPath;
    } finally {
      debugAppProcess?.kill(ProcessSignal.sigterm);
    }
  }

  Future<bool> _probe(String executable, List<String> args) async {
    try {
      final result = await Process.run(
        resolveExecutable(executable),
        args,
        environment: developerToolEnv(),
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
