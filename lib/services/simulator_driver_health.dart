import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/models.dart';
import 'bundled_resources.dart';
import 'xctest_client.dart';

const simulatorDriverRunnerAppName = 'PatrolSimulatorDriverUITests-Runner.app';
const simulatorDriverRunnerZipName = 'PatrolSimulatorDriverUITests-Runner.zip';
const simulatorDriverConfigName = 'patrol-simulator-driver-config.xctestrun';

class SimulatorDriverArtifactReport {
  const SimulatorDriverArtifactReport({
    required this.bundleRootExists,
    required this.configExists,
    required this.runnerAppExists,
    required this.runnerZipExists,
    required this.bundleRootPath,
    this.runnerAppPath,
  });

  final bool bundleRootExists;
  final bool configExists;
  final bool runnerAppExists;
  final bool runnerZipExists;
  final String bundleRootPath;
  final String? runnerAppPath;

  bool get artifactsAvailable => bundleRootExists && configExists;

  bool get runnerBundled => runnerAppExists || runnerZipExists;
}

SimulatorDriverArtifactReport inspectSimulatorDriverArtifacts() {
  final root = resolveBundledResourceRoot('patrol-simulator-driver');
  final simulatorDir = Directory(p.join(root.path, 'simulator'));
  final buildDir = Directory(p.join(simulatorDir.path, 'Debug-iphonesimulator'));
  final config = File(p.join(simulatorDir.path, simulatorDriverConfigName));
  final runnerApp = File(p.join(buildDir.path, simulatorDriverRunnerAppName));
  final runnerZip = File(p.join(buildDir.path, simulatorDriverRunnerZipName));

  return SimulatorDriverArtifactReport(
    bundleRootExists: root.existsSync(),
    configExists: config.existsSync(),
    runnerAppExists: runnerApp.existsSync(),
    runnerZipExists: runnerZip.existsSync(),
    bundleRootPath: root.path,
    runnerAppPath: runnerApp.existsSync() ? runnerApp.path : null,
  );
}

List<HealthCheck> buildSimulatorDriverHealthChecks({
  required SimulatorDriverArtifactReport artifacts,
  DriverStatus? driverStatus,
  bool hasBootedSimulator = false,
}) {
  final checks = <HealthCheck>[];

  checks.add(
    HealthCheck(
      name: 'Simulator driver bundle',
      status: artifacts.artifactsAvailable
          ? HealthStatus.passed
          : HealthStatus.failed,
      explanation: artifacts.artifactsAvailable
          ? 'Patrol simulator driver resources are bundled with Patroller.'
          : 'Patrol simulator driver resources were not found in this install.',
      fixInstruction: artifacts.artifactsAvailable
          ? ''
          : 'Reinstall Patroller or rebuild with scripts/build-simulator-driver.sh.',
      rawOutput: artifacts.bundleRootPath,
    ),
  );

  final runnerExpectedPath = artifacts.runnerAppPath ??
      p.join(
        artifacts.bundleRootPath,
        'simulator',
        'Debug-iphonesimulator',
        simulatorDriverRunnerAppName,
      );

  checks.add(
    HealthCheck(
      name: 'Simulator driver runner app',
      status: artifacts.runnerAppExists || artifacts.runnerZipExists
          ? HealthStatus.passed
          : HealthStatus.failed,
      explanation: artifacts.runnerAppExists || artifacts.runnerZipExists
          ? 'Runner app is bundled and ready to install.'
          : 'PatrolSimulatorDriverUITests-Runner.app is missing from bundled resources.',
      fixInstruction: artifacts.runnerAppExists || artifacts.runnerZipExists
          ? ''
          : 'Reinstall Patroller or run Repair driver after rebuilding simulator driver artifacts.',
      rawOutput: runnerExpectedPath,
    ),
  );

  final driverError = driverStatus?.error?.trim() ?? '';
  if (driverError.toLowerCase().contains('missing')) {
    checks.add(
      HealthCheck(
        name: 'Simulator driver install path',
        status: HealthStatus.failed,
        explanation: driverError,
        fixInstruction:
            'Use Repair driver in Health to clear stale cache and reinstall the runner app.',
        rawOutput: driverError,
      ),
    );
  }

  if (hasBootedSimulator) {
    final state = driverStatus?.state ?? DriverState.idle;
    // Idle/stopped is expected until recording or replay starts the session.
    // Do not treat that as a permanent environment warning.
    final status = switch (state) {
      DriverState.ready || DriverState.idle || DriverState.stopped =>
        HealthStatus.passed,
      DriverState.starting || DriverState.restarting => HealthStatus.warning,
      DriverState.error => HealthStatus.failed,
    };
    checks.add(
      HealthCheck(
        name: 'Simulator driver session',
        status: status,
        explanation: switch (state) {
          DriverState.ready =>
            'Driver session is connected to the selected simulator.',
          DriverState.starting => 'Driver session is starting.',
          DriverState.restarting => 'Driver session is restarting.',
          DriverState.error =>
            driverStatus?.error ?? 'Driver session failed to start.',
          DriverState.stopped =>
            'Driver session is stopped. It will restart when recording or replay begins.',
          DriverState.idle =>
            'Driver session is idle. It starts automatically when recording or replay begins.',
        },
        fixInstruction: switch (state) {
          DriverState.ready || DriverState.idle || DriverState.stopped => '',
          DriverState.starting || DriverState.restarting =>
            'Wait a few seconds for the driver to become ready.',
          DriverState.error =>
            'Use Repair driver, then retry recording or replay.',
        },
        rawOutput: driverStatus?.logTail ?? '',
      ),
    );
  }

  return checks;
}

Future<List<HealthCheck>> probeSimulatorDriverEndpoints({
  required DriverStatus? driverStatus,
}) async {
  if (driverStatus?.state != DriverState.ready || driverStatus?.port == null) {
    return const [];
  }

  final client = XCTestClient(driverStatus!.port!);
  final checks = <HealthCheck>[];

  Future<void> probe({
    required String name,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
      checks.add(
        HealthCheck(
          name: name,
          status: HealthStatus.passed,
          explanation: '$name responded successfully.',
          fixInstruction: '',
          rawOutput: 'ok',
        ),
      );
    } catch (e) {
      checks.add(
        HealthCheck(
          name: name,
          status: HealthStatus.failed,
          explanation: '$name is unavailable: $e',
          fixInstruction: 'Use Repair driver, then retry recording or replay.',
          rawOutput: e.toString(),
        ),
      );
    }
  }

  await probe(name: 'Simulator screenshot endpoint', action: () async {
    final bytes = await client.screenshot(compressed: true);
    if (bytes.isEmpty) throw Exception('Screenshot returned no bytes');
  });
  await probe(name: 'Simulator inspect endpoint', action: () async {
    await client.viewHierarchy();
  });

  return checks;
}

void clearSimulatorDriverCache() {
  final tempRoot =
      Directory(p.join(Directory.systemTemp.path, 'patrol-xctest-runner'));
  if (tempRoot.existsSync()) {
    try {
      tempRoot.deleteSync(recursive: true);
    } catch (_) {}
  }
}