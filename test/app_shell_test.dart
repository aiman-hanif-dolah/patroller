import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/widgets/panel_resize_handle.dart';

void main() {
  group('panel width clamps', () {
    test('logs width cannot hide workspace panel', () {
      const total = 1400.0;
      const right = 380.0;
      final clamped = clampLogsPanelWidth(
        900,
        totalWidth: total,
        rightWidth: right,
      );
      expect(clamped, lessThan(900));
      expect(clamped, greaterThanOrEqualTo(logsPanelMinWidth));
      expect(right + clamped, lessThan(total));
    });

    test('logs width stays within min/max bounds', () {
      final clamped = clampLogsPanelWidth(
        500,
        totalWidth: 1200,
        rightWidth: 380,
      );
      expect(clamped, greaterThanOrEqualTo(logsPanelMinWidth));
      expect(clamped, lessThanOrEqualTo(logsPanelMaxWidth));
      expect(clamped, 500);
    });
  });
}
