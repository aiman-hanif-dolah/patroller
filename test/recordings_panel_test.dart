import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/domain/simulator_driver_readiness.dart';

void main() {
  group('Record tab copy', () {
    test('external-ready state says interact in Simulator.app', () {
      const readiness = SimulatorDriverReadiness(
        embeddedPreviewReady: false,
        embeddedRecordingReady: false,
        canInspect: false,
        userMessage:
            'Interact in Simulator.app — taps and swipes are recorded automatically.',
        fixInstruction: '',
        allowExternalFallback: true,
      );
      expect(
        recordingInstructionCopy(readiness),
        contains('Simulator.app'),
      );
    });

    test('unavailable state explains missing prerequisites', () {
      const readiness = SimulatorDriverReadiness(
        embeddedPreviewReady: false,
        embeddedRecordingReady: false,
        canInspect: false,
        userMessage: 'Boot an iOS Simulator to record actions.',
        fixInstruction: 'Use the device picker below to boot a simulator.',
        allowExternalFallback: false,
      );
      expect(
        recordingInstructionCopy(readiness),
        contains('Boot an iOS Simulator'),
      );
    });

    test('recording action list copy updates while recording', () {
      const ready = SimulatorDriverReadiness(
        embeddedPreviewReady: false,
        embeddedRecordingReady: false,
        canInspect: false,
        userMessage: 'ready',
        fixInstruction: '',
        allowExternalFallback: true,
      );
      expect(
        recordingActiveCopy(readiness: ready, actionCount: 3),
        '3 actions captured from Simulator.app. Logs attach on save.',
      );
    });
  });
}