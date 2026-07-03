import 'package:flutter_test/flutter_test.dart';

String recordingInstructionCopy({required bool previewReady}) {
  return previewReady
      ? 'Interact inside Patroller\'s simulator preview — taps and swipes are recorded automatically.'
      : 'Preview unavailable — interact in Simulator.app and Patroller will record from the native window.';
}

String recordingActiveCopy({
  required bool previewReady,
  required int actionCount,
}) {
  return previewReady
      ? '$actionCount actions captured in preview. Logs attach on save.'
      : 'Use Simulator.app to interact. $actionCount actions captured. Logs attach on save.';
}

void main() {
  group('Record tab copy', () {
    test('preview-ready state says interact in Patroller preview', () {
      expect(
        recordingInstructionCopy(previewReady: true),
        contains('Patroller\'s simulator preview'),
      );
    });

    test('driver-unavailable state falls back to Simulator.app copy', () {
      expect(
        recordingInstructionCopy(previewReady: false),
        contains('Simulator.app'),
      );
    });

    test('recording action list copy updates while recording', () {
      expect(
        recordingActiveCopy(previewReady: true, actionCount: 3),
        '3 actions captured in preview. Logs attach on save.',
      );
      expect(
        recordingActiveCopy(previewReady: false, actionCount: 5),
        contains('5 actions captured'),
      );
    });
  });
}