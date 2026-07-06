import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/models/models.dart';
import 'package:patroller/services/simulator_driver_health.dart';

void main() {
  group('buildSimulatorDriverHealthChecks', () {
    test('warns when only runner zip is bundled', () {
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
      expect(runnerCheck.status, HealthStatus.warning);
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

    test('session check warns when booted simulator has no ready driver', () {
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
      expect(sessionCheck.status, HealthStatus.warning);
    });
  });
}