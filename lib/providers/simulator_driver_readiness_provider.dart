import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/simulator_driver_readiness.dart';
import '../models/models.dart';
import '../services/bundled_resources.dart';
import '../services/simulator_driver_health.dart';
import 'facade_provider.dart';
import 'runner_provider.dart';

final simulatorDriverArtifactsProvider =
    Provider<SimulatorDriverArtifactReport>((ref) {
  return inspectSimulatorDriverArtifacts();
});

final simulatorDriverReadinessProvider =
    Provider<SimulatorDriverReadiness>((ref) {
  final runner = ref.watch(runnerProvider);
  final artifacts = ref.watch(simulatorDriverArtifactsProvider);
  final driverStatus =
      ref.read(patrolStudioFacadeProvider).simulator.driverStatus();
  final device = runner.selectedDevice;
  final hasBootedSimulator =
      device != null && device.state == DeviceState.booted;
  final inputMonitorBundled =
      resolveBundledBinary('simulator-input-monitor', 'simulator-input-monitor') !=
          null;

  return resolveSimulatorDriverReadiness(
    hasBootedSimulator: hasBootedSimulator,
    runnerArtifactsAvailable: artifacts.artifactsAvailable,
    inputMonitorBundled: inputMonitorBundled,
    driverStatus: driverStatus,
  );
});