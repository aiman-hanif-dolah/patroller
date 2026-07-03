import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/models/enums.dart';
import 'package:patroller/models/recording.dart';
import 'package:patroller/providers/recording_provider.dart';

void main() {
  test('recordAction stores device-point swipe coordinates without scaling', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(recordingProvider.notifier);
    notifier.state = container.read(recordingProvider).copyWith(
          isRecording: true,
          startedAt: 1000,
          lastActionAt: 1000,
        );

    notifier.recordAction(
      RecordingActionType.swipe,
      x: 10,
      y: 20,
      toX: 10,
      toY: 120,
    );

    final action = container.read(recordingProvider).activeActions.single;
    expect(action.x, 10);
    expect(action.y, 20);
    expect(action.toX, 10);
    expect(action.toY, 120);
  });

  test('recordAction calculates delay from previous action', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(recordingProvider.notifier);
    notifier.state = container.read(recordingProvider).copyWith(
          isRecording: true,
          startedAt: 1000,
          lastActionAt: 1500,
        );

    notifier.recordAction(RecordingActionType.tap, x: 1, y: 2);

    final action = container.read(recordingProvider).activeActions.single;
    expect(action.delayMs, greaterThanOrEqualTo(0));
  });

  test('recordAction is skipped when not recording', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(recordingProvider.notifier);
    notifier.recordAction(RecordingActionType.tap, x: 1, y: 2);

    expect(container.read(recordingProvider).activeActions, isEmpty);
  });
}