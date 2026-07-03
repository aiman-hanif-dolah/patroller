import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/domain/preview_coordinates.dart';
import 'package:patroller/models/hierarchy.dart';

void main() {
  group('preview coordinate mapping', () {
    late PreviewLayout layout;

    setUp(() {
      layout = computePreviewLayout(
        containerSize: const Size(300, 600),
        deviceWidth: 390,
        deviceHeight: 844,
      );
    });

    test('maps preview point inside image rect to device points', () {
      final center = Offset(
        layout.imageRect.center.dx,
        layout.imageRect.center.dy,
      );
      final device = mapPreviewToDevice(local: center, layout: layout);
      expect(device, isNotNull);
      expect(device!.dx, closeTo(195, 1));
      expect(device.dy, closeTo(422, 1));
    });

    test('ignores taps outside letterboxed image rect', () {
      final outside = const Offset(1, 1);
      expect(mapPreviewToDevice(local: outside, layout: layout), isNull);
    });

    test('maps hierarchy frame back to preview overlay rect', () {
      const frame = ElementFrame(x: 10, y: 20, width: 100, height: 40);
      final rect = mapDeviceFrameToPreview(frame: frame, layout: layout);
      expect(rect, isNotNull);
      expect(rect!.width, greaterThan(0));
      expect(rect.left, greaterThanOrEqualTo(layout.imageRect.left));
    });
  });
}