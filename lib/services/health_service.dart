import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/models.dart';
import 'cli_env.dart';
import 'settings_store.dart';
import 'simulator_driver_health.dart';

class _CommandProbeResult {
  const _CommandProbeResult({
    required this.success,
    required this.stdout,
    required this.stderr,
  });

  final bool success;
  final String stdout;
  final String stderr;
}

int _severityOrder(HealthStatus status) {
  switch (status) {
    case HealthStatus.failed:
      return 0;
    case HealthStatus.warning:
      return 1;
    case HealthStatus.passed:
      return 2;
  }
}

Future<_CommandProbeResult> _runCommand(
  String cmd,
  List<String> args, {
  String? configuredPath,
}) async {
  final executable = resolveExecutable(cmd, configuredPath: configuredPath);
  try {
    final result = await Process.run(
      executable,
      args,
      environment: developerToolEnv(),
      runInShell: false,
    );
    return _CommandProbeResult(
      success: result.exitCode == 0,
      stdout: '${result.stdout}'.trim(),
      stderr: '${result.stderr}'.trim(),
    );
  } catch (e) {
    return _CommandProbeResult(success: false, stdout: '', stderr: e.toString());
  }
}

Future<List<HealthCheck>> runHealthChecks(
  String projectPath, {
  SettingsStore? settingsStore,
  DriverStatus? driverStatus,
  bool hasBootedSimulator = false,
}) async {
  final settings = settingsStore ?? SettingsStore.instance;
  await settings.getAsync();
  final checks = <HealthCheck>[];

  final flutterCheck = await _runCommand(
    'flutter',
    const ['--version'],
    configuredPath: settings.get().flutterPath,
  );
  checks.add(
    HealthCheck(
      name: 'Flutter CLI',
      status: flutterCheck.success ? HealthStatus.passed : HealthStatus.failed,
      explanation: flutterCheck.success
          ? 'Flutter is installed and available.'
          : 'Flutter command was not found on PATH (or Settings path is wrong).',
      fixInstruction: flutterCheck.success
          ? 'No action needed.'
          : 'Install Flutter or set the Flutter path in Patroller Settings (FVM: use the FVM flutter binary).',
      rawOutput: flutterCheck.success
          ? _truncate(flutterCheck.stdout, 200)
          : flutterCheck.stderr,
      copyCommand: flutterCheck.success ? null : 'flutter --version',
    ),
  );

  final dartCheck = await _runCommand(
    'dart',
    const ['--version'],
    configuredPath: settings.get().dartPath,
  );
  checks.add(
    HealthCheck(
      name: 'Dart CLI',
      status: dartCheck.success ? HealthStatus.passed : HealthStatus.failed,
      explanation: dartCheck.success
          ? 'Dart is installed and available.'
          : 'Dart command was not found.',
      fixInstruction: 'Ensure Dart is installed with Flutter or install it separately.',
      rawOutput: dartCheck.success
          ? _truncate(dartCheck.stdout, 200)
          : dartCheck.stderr,
    ),
  );

  final patrolCheck = await _runCommand(
    'patrol',
    const ['--version'],
    configuredPath: settings.get().patrolPath,
  );
  checks.add(
    HealthCheck(
      name: 'Patrol CLI',
      status: patrolCheck.success ? HealthStatus.passed : HealthStatus.failed,
      explanation: patrolCheck.success
          ? 'Patrol CLI is installed (required for Test / Develop).'
          : 'Patrol command was not found.',
      fixInstruction: patrolCheck.success
          ? 'No action needed. Keep patrol_cli compatible with your project patrol package.'
          : 'Install Patrol CLI, then restart Patroller.',
      rawOutput: patrolCheck.success
          ? _truncate(patrolCheck.stdout, 200)
          : patrolCheck.stderr,
      copyCommand:
          patrolCheck.success ? null : 'dart pub global activate patrol_cli',
    ),
  );

  if (Platform.isMacOS) {
    final xcodeCheck = await _runCommand('xcode-select', const ['-p']);
    checks.add(
      HealthCheck(
        name: 'Xcode Command Line Tools',
        status: xcodeCheck.success ? HealthStatus.passed : HealthStatus.failed,
        explanation: xcodeCheck.success
            ? 'Xcode tools at: ${xcodeCheck.stdout}'
            : 'Xcode command line tools not found.',
        fixInstruction:
            'Install Xcode from the Mac App Store, then run xcode-select --install if needed.',
        rawOutput: xcodeCheck.stdout.isNotEmpty ? xcodeCheck.stdout : xcodeCheck.stderr,
      ),
    );

    final xcrunCheck = await _runCommand(
      'xcrun',
      const ['--version'],
      configuredPath: settings.get().xcrunPath,
    );
    checks.add(
      HealthCheck(
        name: 'xcrun',
        status: xcrunCheck.success ? HealthStatus.passed : HealthStatus.failed,
        explanation: xcrunCheck.success ? 'xcrun is available.' : 'xcrun not found.',
        fixInstruction: 'xcrun is part of Xcode. Install Xcode command line tools.',
        rawOutput: xcrunCheck.stdout.isNotEmpty ? xcrunCheck.stdout : xcrunCheck.stderr,
      ),
    );

    final simctlCheck = await _runCommand(
      'xcrun',
      const ['simctl', 'list', 'devices', '--json'],
      configuredPath: settings.get().xcrunPath,
    );
    checks.add(
      HealthCheck(
        name: 'iOS Simulator',
        status: simctlCheck.success ? HealthStatus.passed : HealthStatus.failed,
        explanation: simctlCheck.success
            ? 'iOS Simulator is available. Patroller runs currently target iOS Simulator only.'
            : 'Unable to list iOS Simulators.',
        fixInstruction: simctlCheck.success
            ? 'Boot a simulator from the device picker before Test / Develop.'
            : 'Install Xcode which includes iOS Simulator.',
        rawOutput: simctlCheck.success
            ? 'Found iOS Simulator devices.'
            : _truncate(simctlCheck.stderr, 300),
        copyCommand: simctlCheck.success
            ? 'xcrun simctl list devices booted'
            : 'xcode-select --install',
      ),
    );
  }

  final pubspecPath = p.join(projectPath, 'pubspec.yaml');
  final hasPubspec = File(pubspecPath).existsSync();
  checks.add(
    HealthCheck(
      name: 'Project pubspec.yaml',
      status: hasPubspec ? HealthStatus.passed : HealthStatus.failed,
      explanation: hasPubspec
          ? 'pubspec.yaml found in project.'
          : 'No pubspec.yaml found in the selected folder.',
      fixInstruction: 'Open a valid Flutter project that contains pubspec.yaml.',
      rawOutput: hasPubspec ? 'Found at $pubspecPath' : 'Not found',
    ),
  );

  if (hasPubspec) {
    final pubspecContent = File(pubspecPath).readAsStringSync();
    final hasPatrol = pubspecContent.contains('patrol:');
    checks.add(
      HealthCheck(
        name: 'Patrol dependency',
        status: hasPatrol ? HealthStatus.passed : HealthStatus.warning,
        explanation: hasPatrol
            ? 'Patrol is listed in pubspec - if CLI patrol test already works, you need no extra project setup for Patroller.'
            : 'Patrol is not found in pubspec.yaml dependencies.',
        fixInstruction: hasPatrol
            ? 'Open this project, pick an iOS Simulator, and run Test / Develop.'
            : 'Add patrol to dev_dependencies, or open a project where Patrol already works.',
        rawOutput: hasPatrol ? 'patrol dependency found' : 'patrol dependency not found',
        copyCommand: hasPatrol ? null : 'flutter pub add patrol --dev',
      ),
    );
  }

  final testDirPath = p.join(
    projectPath,
    settings.get().testDirectory,
  );
  final hasTestDir = Directory(testDirPath).existsSync();
  checks.add(
    HealthCheck(
      name: 'patrol_test directory',
      status: hasTestDir ? HealthStatus.passed : HealthStatus.warning,
      explanation: hasTestDir
          ? 'patrol_test directory exists.'
          : 'No patrol_test folder was found.',
      fixInstruction:
          'Create a patrol_test folder or configure the correct test directory in settings.',
      rawOutput: hasTestDir ? 'Found at $testDirPath' : 'Not found',
    ),
  );

  if (hasTestDir) {
    final testFiles = _findTestFiles(Directory(testDirPath));
    checks.add(
      HealthCheck(
        name: 'Test files',
        status: testFiles.isNotEmpty ? HealthStatus.passed : HealthStatus.warning,
        explanation: testFiles.isNotEmpty
            ? 'Found ${testFiles.length} test file(s).'
            : 'No files ending with _test.dart found.',
        fixInstruction:
            'Create test files ending with _test.dart in the Patrol test directory.',
        rawOutput: testFiles.isEmpty ? 'None found' : testFiles.join('\n'),
      ),
    );
  }

  if (Platform.isMacOS) {
    final artifacts = inspectSimulatorDriverArtifacts();
    checks.addAll(
      buildSimulatorDriverHealthChecks(
        artifacts: artifacts,
        driverStatus: driverStatus,
        hasBootedSimulator: hasBootedSimulator,
      ),
    );
    checks.addAll(
      await probeSimulatorDriverEndpoints(driverStatus: driverStatus),
    );
  }

  checks.sort((a, b) => _severityOrder(a.status).compareTo(_severityOrder(b.status)));
  return checks;
}

String _truncate(String value, int maxLength) {
  if (value.length <= maxLength) return value;
  return value.substring(0, maxLength);
}

List<String> _findTestFiles(Directory dir) {
  final results = <String>[];
  if (!dir.existsSync()) return results;

  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.endsWith('_test.dart')) {
      results.add(p.basename(entity.path));
    }
  }
  return results;
}