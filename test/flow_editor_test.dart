import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/domain/flow_editor.dart';
import 'package:patroller/models/recording.dart';

RecordingAction _tap(String id, {String? label, int delayMs = 0}) {
  return RecordingAction(
    id: id,
    type: RecordingActionType.tap,
    timestampMs: 0,
    delayMs: delayMs,
    x: 10,
    y: 20,
    targetLabel: label,
  );
}

void main() {
  group('flow_editor helpers', () {
    test('removeFlowStep drops by id', () {
      final actions = [_tap('a'), _tap('b'), _tap('c')];
      final next = removeFlowStep(actions, 'b');
      expect(next.map((a) => a.id), ['a', 'c']);
    });

    test('moveFlowStep up and down', () {
      final actions = [_tap('a'), _tap('b'), _tap('c')];
      expect(moveFlowStep(actions, 'b', -1).map((a) => a.id), ['b', 'a', 'c']);
      expect(moveFlowStep(actions, 'b', 1).map((a) => a.id), ['a', 'c', 'b']);
      expect(moveFlowStep(actions, 'a', -1).map((a) => a.id), ['a', 'b', 'c']);
      expect(moveFlowStep(actions, 'c', 1).map((a) => a.id), ['a', 'b', 'c']);
    });

    test('insertAssertVisible inserts at index with label', () {
      final actions = [_tap('a'), _tap('b')];
      final next = insertAssertVisible(
        actions,
        index: 1,
        label: 'Home',
        id: 'assert-1',
      );
      expect(next.length, 3);
      expect(next[1].id, 'assert-1');
      expect(next[1].type, RecordingActionType.assertVisible);
      expect(next[1].targetLabel, 'Home');
    });

    test('patchFlowStep updates label and delay', () {
      final action = _tap('a', label: 'Old', delayMs: 0);
      final patched = patchFlowStep(action, targetLabel: 'New', delayMs: 250);
      expect(patched.targetLabel, 'New');
      expect(patched.delayMs, 250);
      expect(patched.id, 'a');
    });

    test('flowStepTitle for assert and tap', () {
      expect(
        flowStepTitle(
          RecordingAction(
            id: '1',
            type: RecordingActionType.assertVisible,
            timestampMs: 0,
            delayMs: 0,
            targetLabel: 'Profile',
          ),
        ),
        'assert "Profile" visible',
      );
      expect(flowStepTitle(_tap('1', label: 'Login')), 'tap "Login"');
    });
  });
}
