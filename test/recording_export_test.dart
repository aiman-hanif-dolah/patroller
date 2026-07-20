import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/models/enums.dart';
import 'package:patroller/models/recording.dart';
import 'package:patroller/services/recording_export.dart';

Recording _recording(List<RecordingAction> actions) {
  return Recording(
    id: 'rec-1',
    name: 'Login flow',
    projectPath: '/tmp/demo',
    createdAt: '2026-01-01T00:00:00Z',
    updatedAt: '2026-01-01T00:00:00Z',
    environmentProfile: RecordingEnvironmentProfile.live,
    actionCount: actions.length,
    durationMs: 1000,
    actions: actions,
    logs: const [],
  );
}

void main() {
  group('toPatrolTest', () {
    test('uses label finder for tap when targetLabel set', () {
      final dart = toPatrolTest(
        _recording([
          RecordingAction(
            id: 'a1',
            type: RecordingActionType.tap,
            timestampMs: 0,
            delayMs: 0,
            x: 12,
            y: 34,
            targetLabel: 'Continue',
          ),
        ]),
      );
      expect(dart, contains(r'await $("Continue").tap();'));
      expect(dart, isNot(contains('tapAt')));
      expect(dart, contains('patrolTest'));
    });

    test('falls back to coordinates without label', () {
      final dart = toPatrolTest(
        _recording([
          RecordingAction(
            id: 'a1',
            type: RecordingActionType.tap,
            timestampMs: 0,
            delayMs: 0,
            x: 12,
            y: 34,
          ),
        ]),
      );
      expect(dart, contains('tapAt(const Offset(12, 34))'));
    });

    test('emits waitUntilVisible for assertVisible', () {
      final dart = toPatrolTest(
        _recording([
          RecordingAction(
            id: 'a1',
            type: RecordingActionType.assertVisible,
            timestampMs: 0,
            delayMs: 100,
            targetLabel: 'Home',
          ),
        ]),
      );
      expect(dart, contains('milliseconds: 100'));
      expect(dart, contains(r'await $("Home").waitUntilVisible();'));
    });

    test('mergeTextActions collapses consecutive text', () {
      final merged = mergeTextActions([
        RecordingAction(
          id: 't1',
          type: RecordingActionType.text,
          timestampMs: 0,
          delayMs: 0,
          text: 'ab',
        ),
        RecordingAction(
          id: 't2',
          type: RecordingActionType.text,
          timestampMs: 10,
          delayMs: 0,
          text: 'cd',
        ),
        RecordingAction(
          id: 'tap',
          type: RecordingActionType.tap,
          timestampMs: 20,
          delayMs: 0,
          x: 1,
          y: 2,
        ),
      ]);
      expect(merged.length, 2);
      expect(merged.first.text, 'abcd');
      expect(merged.last.type, RecordingActionType.tap);
    });

    test('exportRecording flow includes assertVisible', () {
      final exported = exportRecording(
        _recording([
          RecordingAction(
            id: 'a1',
            type: RecordingActionType.assertVisible,
            timestampMs: 0,
            delayMs: 0,
            targetLabel: 'Settings',
          ),
        ]),
      );
      expect(exported.flow, contains('assertVisible'));
      expect(exported.flow, contains('Settings'));
      expect(exported.patrolTest, contains('waitUntilVisible'));
    });
  });
}
