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
        logsCollapsed: false,
        rightCollapsed: false,
      );
      expect(clamped, lessThan(900));
      expect(clamped, greaterThanOrEqualTo(logsPanelMinWidth));
      expect(right + clamped, lessThan(total));
    });

    test('collapsed logs frees horizontal space', () {
      final expanded = clampLogsPanelWidth(
        500,
        totalWidth: 1200,
        rightWidth: 380,
        logsCollapsed: false,
        rightCollapsed: false,
      );
      final collapsed = clampLogsPanelWidth(
        500,
        totalWidth: 1200,
        rightWidth: 380,
        logsCollapsed: true,
        rightCollapsed: false,
      );
      expect(collapsed, lessThan(expanded));
    });
  });
}