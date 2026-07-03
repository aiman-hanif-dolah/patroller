import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/domain/preview_coordinates.dart';
import 'package:patroller/domain/preview_gestures.dart';
import 'package:patroller/models/preview_frame.dart';

void main() {
  group('classifyPointerGesture', () {
    test('short click becomes tap', () {
      final gesture = classifyPointerGesture(
        start: const Offset(10, 10),
        end: const Offset(11, 11),
        elapsed: const Duration(milliseconds: 80),
      );
      expect(gesture.kind, PreviewGestureKind.tap);
    });

    test('long hold becomes long press', () {
      final gesture = classifyPointerGesture(
        start: const Offset(10, 10),
        end: const Offset(10, 10),
        elapsed: const Duration(milliseconds: 700),
      );
      expect(gesture.kind, PreviewGestureKind.longPress);
    });

    test('drag above threshold becomes swipe', () {
      final gesture = classifyPointerGesture(
        start: const Offset(10, 10),
        end: const Offset(10, 80),
        elapsed: const Duration(milliseconds: 200),
      );
      expect(gesture.kind, PreviewGestureKind.swipe);
      expect(gesture.end, const Offset(10, 80));
    });
  });

  group('scrollGestureFromWheel', () {
    test('maps wheel delta to vertical swipe in device points', () {
      final layout = computePreviewLayout(
        containerSize: const Size(300, 600),
        deviceWidth: 390,
        deviceHeight: 844,
      );
      final scroll = scrollGestureFromWheel(
        devicePoint: const Offset(195, 422),
        scrollDeltaY: 40,
        layout: layout,
      );
      expect(scroll.end.dy, lessThan(scroll.start.dy));
    });
  });
}