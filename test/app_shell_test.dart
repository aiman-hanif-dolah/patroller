import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/features/devices/simulator_preview_panel.dart';
import 'package:patroller/widgets/panel_resize_handle.dart';

void main() {
  group('panel width clamps', () {
    test('preview width stays within bounds', () {
      expect(clampPreviewPanelWidth(200), previewPanelMinWidth);
      expect(clampPreviewPanelWidth(600), previewPanelMaxWidth);
      expect(clampPreviewPanelWidth(390), 390);
    });

    test('logs width cannot hide preview and right panel', () {
      const total = 1400.0;
      const preview = 390.0;
      const right = 380.0;
      final clamped = clampLogsPanelWidth(
        900,
        totalWidth: total,
        previewWidth: preview,
        rightWidth: right,
        previewCollapsed: false,
      );
      expect(clamped, lessThan(900));
      expect(clamped, greaterThanOrEqualTo(logsPanelMinWidth));
      expect(preview + right + clamped, lessThan(total));
    });

    test('collapsed preview frees horizontal space for logs', () {
      final expanded = clampLogsPanelWidth(
        500,
        totalWidth: 1200,
        previewWidth: 390,
        rightWidth: 380,
        previewCollapsed: false,
      );
      final collapsed = clampLogsPanelWidth(
        500,
        totalWidth: 1200,
        previewWidth: 390,
        rightWidth: 380,
        previewCollapsed: true,
      );
      expect(collapsed, greaterThanOrEqualTo(expanded));
    });
  });

  group('SimulatorPreviewPanel', () {
    testWidgets('expanded preview shows collapse control', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SimulatorPreviewPanel(
                collapsed: false,
                onToggleCollapse: _noop,
              ),
            ),
          ),
        ),
      );
      expect(find.byTooltip('Collapse preview'), findsOneWidget);
    });

    testWidgets('collapsed preview shows expand affordance', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SimulatorPreviewPanel(
                collapsed: true,
                onToggleCollapse: _noop,
              ),
            ),
          ),
        ),
      );
      expect(find.text('PREVIEW'), findsOneWidget);
    });
  });
}

void _noop() {}