import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/models/models.dart';
import 'package:patroller/services/simulator_driver_health.dart';

void main() {
  group('buildSimulatorDriverHealthChecks', () {
    test('passes when only runner zip is bundled', () {
      const artifacts = SimulatorDriverArtifactReport(
        bundleRootExists: true,
        configExists: true,
        runnerAppExists: false,
        runnerZipExists: true,
        bundleRootPath: '/tmp/patrol-simulator-driver',
      );
      final checks = buildSimulatorDriverHealthChecks(artifacts: artifacts);
      final runnerCheck = checks.firstWhere(
        (check) => check.name == 'Simulator driver runner app',
      );
      expect(runnerCheck.status, HealthStatus.passed);
    });

    test('fails when runner app and zip are missing', () {
      const artifacts = SimulatorDriverArtifactReport(
        bundleRootExists: true,
        configExists: true,
        runnerAppExists: false,
        runnerZipExists: false,
        bundleRootPath: '/tmp/patrol-simulator-driver',
      );
      final checks = buildSimulatorDriverHealthChecks(artifacts: artifacts);
      final runnerCheck = checks.firstWhere(
        (check) => check.name == 'Simulator driver runner app',
      );
      expect(runnerCheck.status, HealthStatus.failed);
    });

    test('session check passes when booted simulator driver is idle', () {
      const artifacts = SimulatorDriverArtifactReport(
        bundleRootExists: true,
        configExists: true,
        runnerAppExists: true,
        runnerZipExists: false,
        bundleRootPath: '/tmp/patrol-simulator-driver',
        runnerAppPath: '/tmp/runner.app',
      );
      final checks = buildSimulatorDriverHealthChecks(
        artifacts: artifacts,
        hasBootedSimulator: true,
        driverStatus: const DriverStatus(state: DriverState.idle),
      );
      final sessionCheck = checks.firstWhere(
        (check) => check.name == 'Simulator driver session',
      );
      expect(sessionCheck.status, HealthStatus.passed);
      expect(sessionCheck.explanation, contains('idle'));
      expect(sessionCheck.fixInstruction, isEmpty);
    });

    test('session check passes when driver is stopped', () {
      const artifacts = SimulatorDriverArtifactReport(
        bundleRootExists: true,
        configExists: true,
        runnerAppExists: true,
        runnerZipExists: false,
        bundleRootPath: '/tmp/patrol-simulator-driver',
        runnerAppPath: '/tmp/runner.app',
      );
      final checks = buildSimulatorDriverHealthChecks(
        artifacts: artifacts,
        hasBootedSimulator: true,
        driverStatus: const DriverStatus(state: DriverState.stopped),
      );
      final sessionCheck = checks.firstWhere(
        (check) => check.name == 'Simulator driver session',
      );
      expect(sessionCheck.status, HealthStatus.passed);
      expect(sessionCheck.fixInstruction, isEmpty);
    });

    test('session check fails when driver is in error', () {
      const artifacts = SimulatorDriverArtifactReport(
        bundleRootExists: true,
        configExists: true,
        runnerAppExists: true,
        runnerZipExists: false,
        bundleRootPath: '/tmp/patrol-simulator-driver',
        runnerAppPath: '/tmp/runner.app',
      );
      final checks = buildSimulatorDriverHealthChecks(
        artifacts: artifacts,
        hasBootedSimulator: true,
        driverStatus: const DriverStatus(
          state: DriverState.error,
          error: 'Port 22087 is in use',
        ),
      );
      final sessionCheck = checks.firstWhere(
        (check) => check.name == 'Simulator driver session',
      );
      expect(sessionCheck.status, HealthStatus.failed);
      expect(sessionCheck.explanation, contains('Port 22087'));
      expect(sessionCheck.fixInstruction, contains('Repair driver'));
    });

    test('session check warns while driver is starting', () {
      const artifacts = SimulatorDriverArtifactReport(
        bundleRootExists: true,
        configExists: true,
        runnerAppExists: true,
        runnerZipExists: false,
        bundleRootPath: '/tmp/patrol-simulator-driver',
        runnerAppPath: '/tmp/runner.app',
      );
      final checks = buildSimulatorDriverHealthChecks(
        artifacts: artifacts,
        hasBootedSimulator: true,
        driverStatus: const DriverStatus(state: DriverState.starting),
      );
      final sessionCheck = checks.firstWhere(
        (check) => check.name == 'Simulator driver session',
      );
      expect(sessionCheck.status, HealthStatus.warning);
      expect(sessionCheck.fixInstruction, contains('Wait'));
    });

    test('omits session check when no simulator is booted', () {
      const artifacts = SimulatorDriverArtifactReport(
        bundleRootExists: true,
        configExists: true,
        runnerAppExists: true,
        runnerZipExists: false,
        bundleRootPath: '/tmp/patrol-simulator-driver',
        runnerAppPath: '/tmp/runner.app',
      );
      final checks = buildSimulatorDriverHealthChecks(
        artifacts: artifacts,
        hasBootedSimulator: false,
        driverStatus: const DriverStatus(state: DriverState.idle),
      );
      expect(
        checks.any((check) => check.name == 'Simulator driver session'),
        isFalse,
      );
    });
  });
}