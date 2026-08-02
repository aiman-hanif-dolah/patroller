import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/routine_models.dart';
import 'cli_env.dart';

class ProjectCommandResult {
  const ProjectCommandResult({
    required this.ok,
    required this.command,
    required this.output,
  });

  final bool ok;
  final String command;
  final String output;
}

class ProjectToolingService {
  Future<List<ProjectDependency>> listDependencies(String projectPath) async {
    final file = File(p.join(projectPath, 'pubspec.yaml'));
    if (!file.existsSync()) return const [];
    return parseDependencies(await file.readAsString());
  }

  List<ProjectDependency> parseDependencies(String content) {
    final result = <ProjectDependency>[];
    String? section;
    for (final raw in content.split('\n')) {
      final line = raw.replaceAll('\t', '    ');
      if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
      if (!line.startsWith(' ') && !line.startsWith('-')) {
        final match = RegExp(
          r'^(dependencies|dev_dependencies|dependency_overrides):\s*$',
        ).firstMatch(line.trim());
        section = match?.group(1);
        continue;
      }
      if (section == null || line.trimLeft().startsWith('#')) continue;
      final match = RegExp(
        r'^\s{2}([A-Za-z0-9_][A-Za-z0-9_-]*):\s*(.*)$',
      ).firstMatch(line);
      if (match == null) continue;
      final value = match.group(2)!.trim();
      if (value.startsWith('{') || value.isEmpty) continue;
      result.add(
        ProjectDependency(
          name: match.group(1)!,
          section: section,
          constraint: value,
          source: value.contains(':') ? value.split(':').first : null,
        ),
      );
    }
    return result;
  }

  Future<ProjectCommandResult> pubGet(String projectPath) =>
      _run(projectPath, const ['pub', 'get'], 'flutter pub get');

  Future<ProjectCommandResult> runPatrolSweep(String projectPath) async {
    try {
      final result = await Process.run(
        resolveExecutable('patrol'),
        const ['test'],
        workingDirectory: projectPath,
        environment: developerToolEnv(),
      );
      return ProjectCommandResult(
        ok: result.exitCode == 0,
        command: 'patrol test',
        output: '${result.stdout}${result.stderr}'.trim(),
      );
    } catch (error) {
      return ProjectCommandResult(
        ok: false,
        command: 'patrol test',
        output: '$error',
      );
    }
  }

  Future<ProjectCommandResult> installPatrolCli() async {
    try {
      final dart = resolveExecutable('dart');
      final result = await Process.run(dart, const [
        'pub',
        'global',
        'activate',
        'patrol_cli',
      ], environment: developerToolEnv());
      return ProjectCommandResult(
        ok: result.exitCode == 0,
        command: 'dart pub global activate patrol_cli',
        output: '${result.stdout}${result.stderr}'.trim(),
      );
    } catch (error) {
      return ProjectCommandResult(
        ok: false,
        command: 'dart pub global activate patrol_cli',
        output: '$error',
      );
    }
  }

  Future<ProjectCommandResult> addDependency(
    String projectPath,
    String package, {
    bool dev = false,
  }) {
    final args = <String>['pub', 'add'];
    if (dev) args.add('--dev');
    args.add(package);
    return _run(projectPath, args, 'flutter ${args.join(' ')}');
  }

  Future<ProjectCommandResult> removeDependency(
    String projectPath,
    String package,
  ) => _run(projectPath, [
    'pub',
    'remove',
    package,
  ], 'flutter pub remove $package');

  Future<bool> hasCleanGitWorktree(String projectPath) async {
    try {
      final result = await Process.run(
        'git',
        const ['status', '--porcelain'],
        workingDirectory: projectPath,
        environment: developerToolEnv(),
      );
      return result.exitCode == 0 && '${result.stdout}'.trim().isEmpty;
    } catch (_) {
      return false;
    }
  }

  String? findEntrypoint(String projectPath) {
    final candidates = [
      'lib/main.dart',
      'lib/main_dev.dart',
      'lib/main_stg.dart',
      'lib/main_staging.dart',
    ];
    final found = candidates
        .where((candidate) => File(p.join(projectPath, candidate)).existsSync())
        .toList();
    return found.length == 1
        ? found.single
        : (found.contains('lib/main.dart') ? 'lib/main.dart' : null);
  }

  Future<ProjectCommandResult> setupNativePatrolHost(String projectPath) async {
    final iosRunnerTestsDir = Directory(p.join(projectPath, 'ios', 'RunnerTests'));
    if (!iosRunnerTestsDir.existsSync()) {
      await iosRunnerTestsDir.create(recursive: true);
    }
    final swiftFile = File(p.join(iosRunnerTestsDir.path, 'RunnerTests.swift'));
    if (!swiftFile.existsSync()) {
      await swiftFile.writeAsString('''import XCTest
import Patrol
import Runner

class RunnerTests: PatrolJUnitTestRunner {
  override class func setUp() {
    PatrolJUnitTestRunner.setUp()
  }
}
''');
    }

    final androidDir = Directory(
      p.join(projectPath, 'android', 'app', 'src', 'androidTest', 'java', 'com', 'example', 'app'),
    );
    if (!androidDir.existsSync()) {
      await androidDir.create(recursive: true);
    }
    final androidFile = File(p.join(androidDir.path, 'MainActivityTest.kt'));
    if (!androidFile.existsSync()) {
      await androidFile.writeAsString('''package com.example.app

import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import pl.leancode.patrol.PatrolTestRunner

@RunWith(PatrolTestRunner::class)
class MainActivityTest {
    @Test
    fun testEntryPoint() {}
}
''');
    }

    return const ProjectCommandResult(
      ok: true,
      command: 'setup-native-host',
      output: 'Wired native Patrol test runner files for iOS and Android',
    );
  }

  Future<RoutineReadinessReport> inspect({
    required String projectPath,
    String? selectedDevice,
  }) async {
    final checks = <RoutineCheck>[];
    final pubspec = File(p.join(projectPath, 'pubspec.yaml'));
    final validProject =
        Directory(projectPath).existsSync() && pubspec.existsSync();
    checks.add(
      RoutineCheck(
        id: 'project',
        label: 'Flutter project',
        ok: validProject,
        detail: validProject
            ? 'pubspec.yaml found'
            : 'Select a Flutter project root',
      ),
    );
    if (!validProject) {
      return RoutineReadinessReport(
        status: RoutineReadiness.blocked,
        checks: checks,
        projectPath: projectPath,
        preview: const [],
      );
    }

    final dependencies = await listDependencies(projectPath);
    bool has(String name) =>
        dependencies.any((dependency) => dependency.name == name);
    final hasPatrol = has('patrol');
    final hasIntegration = has('integration_test');
    final hasPatrolMcp = has('patrol_mcp');
    final hasMarionette = has('marionette_flutter');
    checks.add(
      RoutineCheck(
        id: 'patrol',
        label: 'Patrol dependency',
        ok: hasPatrol,
        repairable: true,
        detail: hasPatrol
            ? 'Found in pubspec.yaml'
            : 'Missing from pubspec.yaml',
        fixCommand: hasPatrol ? null : 'flutter pub add --dev patrol',
      ),
    );
    checks.add(
      RoutineCheck(
        id: 'integration_test',
        label: 'integration_test dependency',
        ok: hasIntegration,
        repairable: true,
        detail: hasIntegration
            ? 'Found in pubspec.yaml'
            : 'Missing from pubspec.yaml',
        fixCommand: hasIntegration
            ? null
            : 'flutter pub add --dev integration_test',
      ),
    );
    checks.add(
      RoutineCheck(
        id: 'patrol_mcp',
        label: 'Project Patrol MCP',
        ok: hasPatrolMcp,
        repairable: true,
        detail: hasPatrolMcp
            ? 'Found in pubspec.yaml'
            : 'Missing from pubspec.yaml',
        fixCommand: hasPatrolMcp ? null : 'flutter pub add --dev patrol_mcp',
      ),
    );
    checks.add(
      RoutineCheck(
        id: 'marionette_flutter',
        label: 'Marionette Flutter bridge',
        ok: hasMarionette,
        repairable: true,
        detail: hasMarionette
            ? 'Found in pubspec.yaml'
            : 'Missing from pubspec.yaml',
        fixCommand: hasMarionette ? null : 'flutter pub add marionette_flutter',
      ),
    );

    final testDir = Directory(p.join(projectPath, 'patrol_test'));
    checks.add(
      RoutineCheck(
        id: 'tests',
        label: 'Patrol test directory',
        ok: testDir.existsSync(),
        detail: testDir.existsSync()
            ? 'patrol_test/ found'
            : 'No patrol_test/ directory yet',
        repairable: true,
      ),
    );
    final entrypoint = findEntrypoint(projectPath);
    final bridgeReady =
        entrypoint != null &&
        File(
          p.join(projectPath, entrypoint),
        ).readAsStringSync().contains('MarionetteBinding');
    checks.add(
      RoutineCheck(
        id: 'marionette_binding',
        label: 'Debug Marionette binding',
        ok: bridgeReady,
        detail: bridgeReady
            ? 'Binding found in $entrypoint'
            : 'Debug binding is not configured',
        repairable: entrypoint != null,
      ),
    );
    checks.add(
      RoutineCheck(
        id: 'device',
        label: 'Selected iOS Simulator',
        ok:
            Platform.isMacOS &&
            selectedDevice != null &&
            selectedDevice.trim().isNotEmpty,
        detail: Platform.isMacOS && selectedDevice != null
            ? selectedDevice
            : 'Select a booted iOS Simulator',
      ),
    );

    final cleanGit = await hasCleanGitWorktree(projectPath);
    checks.add(
      RoutineCheck(
        id: 'git',
        label: 'Clean Git worktree',
        ok: cleanGit,
        detail: cleanGit
            ? 'Clean Git worktree'
            : 'Uncommitted changes present (dirty worktree override available)',
        repairable: true,
      ),
    );

    final hasIosHost = Directory(p.join(projectPath, 'ios', 'RunnerTests')).existsSync();
    final hasAndroidHost = Directory(p.join(projectPath, 'android', 'app', 'src', 'androidTest')).existsSync();
    final hostWiringOk = Platform.isMacOS ? hasIosHost : (Platform.isAndroid ? hasAndroidHost : (hasIosHost || hasAndroidHost));
    checks.add(
      RoutineCheck(
        id: 'patrol_host_wiring',
        label: 'Patrol native host wiring',
        ok: hostWiringOk,
        detail: hostWiringOk
            ? 'Native test runner files detected'
            : 'Native Patrol host setup missing (auto-wiring available)',
        repairable: true,
        fixCommand: hostWiringOk ? null : 'setup-native-host',
      ),
    );

    final failures = checks.where((check) => !check.ok).toList();
    final blocked = failures.any((check) => !check.repairable);
    return RoutineReadinessReport(
      status: failures.isEmpty
          ? RoutineReadiness.ready
          : blocked
          ? RoutineReadiness.blocked
          : RoutineReadiness.repairable,
      checks: checks,
      projectPath: projectPath,
      entrypoint: entrypoint,
      selectedDevice: selectedDevice,
      preview: failures
          .where((check) => check.fixCommand != null)
          .map((check) => check.fixCommand!)
          .toList(),
    );
  }

  Future<ProjectCommandResult> _run(
    String projectPath,
    List<String> args,
    String command,
  ) async {
    try {
      final result = await Process.run(
        'flutter',
        args,
        workingDirectory: projectPath,
        environment: developerToolEnv(),
      );
      final output = '${result.stdout}${result.stderr}'.trim();
      return ProjectCommandResult(
        ok: result.exitCode == 0,
        command: command,
        output: output,
      );
    } catch (error) {
      return ProjectCommandResult(
        ok: false,
        command: command,
        output: '$error',
      );
    }
  }
}
