import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/domain/simulator_driver_readiness.dart';
import 'package:patroller/models/models.dart';
import 'package:patroller/providers/health_provider.dart';

void main() {
  group('resolveSimulatorDriverReadiness', () {
    test('fails when input monitor is missing', () {
      final readiness = resolveSimulatorDriverReadiness(
        hasBootedSimulator: true,
        runnerArtifactsAvailable: true,
        inputMonitorBundled: false,
      );
      expect(readiness.allowExternalFallback, false);
      expect(readiness.userMessage, contains('input monitor'));
    });

    test('external recording ready with booted simulator', () {
      final readiness = resolveSimulatorDriverReadiness(
        hasBootedSimulator: true,
        runnerArtifactsAvailable: true,
        inputMonitorBundled: true,
      );
      expect(readiness.allowExternalFallback, true);
      expect(readiness.embeddedRecordingReady, true);
      expect(readiness.canInspect, false);
      expect(
        recordingInstructionCopy(readiness),
        contains('Simulator.app'),
      );
    });

    test('requires booted simulator before recording', () {
      final readiness = resolveSimulatorDriverReadiness(
        hasBootedSimulator: false,
        runnerArtifactsAvailable: true,
        inputMonitorBundled: true,
      );
      expect(readiness.allowExternalFallback, false);
      expect(readiness.userMessage, contains('Boot'));
    });
  });

  group('display labels', () {
    test('history filter avoids queue terminology', () {
      expect(historyFilterLabel('batches'), 'Batches');
      expect(historyFilterLabel('queues'), 'queues');
    });

    test('tests filter uses selected not queued', () {
      expect(testsFilterLabel('selected'), 'Selected');
      expect(testsFilterLabel('runnable'), 'Runnable');
    });
  });

  group('formatHealthStripLabel', () {
    test('unchecked shows Not checked', () {
      expect(
        formatHealthStripLabel(const HealthState()),
        'Not checked',
      );
    });
  });
}