import 'dart:math' as math;
import 'dart:ui';

import '../models/preview_frame.dart';
import 'preview_coordinates.dart';

const double swipeThresholdDevicePoints = 8;
const int longPressThresholdMs = 500;
const double scrollMinDelta = 0.5;
const double scrollDeviceDistancePoints = 80;

class ClassifiedGesture {
  const ClassifiedGesture({
    required this.kind,
    required this.start,
    this.end,
    this.durationSec,
  });

  final PreviewGestureKind kind;
  final Offset start;
  final Offset? end;
  final double? durationSec;
}

ClassifiedGesture classifyPointerGesture({
  required Offset start,
  required Offset end,
  required Duration elapsed,
}) {
  final distance = (end - start).distance;
  if (distance >= swipeThresholdDevicePoints) {
    final durationSec = (elapsed.inMilliseconds / 1000.0).clamp(0.1, 1.5);
    return ClassifiedGesture(
      kind: PreviewGestureKind.swipe,
      start: start,
      end: end,
      durationSec: durationSec,
    );
  }
  if (elapsed.inMilliseconds >= longPressThresholdMs) {
    return ClassifiedGesture(
      kind: PreviewGestureKind.longPress,
      start: start,
      durationSec: elapsed.inMilliseconds / 1000.0,
    );
  }
  return ClassifiedGesture(kind: PreviewGestureKind.tap, start: start);
}

({Offset start, Offset end, double durationSec}) scrollGestureFromWheel({
  required Offset devicePoint,
  required double scrollDeltaY,
  required PreviewLayout layout,
}) {
  final scaleY = layout.deviceHeight / layout.imageRect.height;
  final deviceDelta = scrollDeltaY * scaleY;
  final distance = math.max(
    scrollDeviceDistancePoints,
    deviceDelta.abs().clamp(20, 240),
  );
  final direction = scrollDeltaY > 0 ? -1.0 : 1.0;
  final endY = (devicePoint.dy + direction * distance)
      .clamp(0.0, layout.deviceHeight);
  return (
    start: devicePoint,
    end: Offset(devicePoint.dx, endY),
    durationSec: 0.25,
  );
}