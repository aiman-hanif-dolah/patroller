import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/models/app_settings.dart';

void main() {
  group('AppSettings preview layout defaults', () {
    test('defaults include preview panel settings', () {
      final settings = AppSettings.defaults();
      expect(settings.previewPanelWidth, 390);
      expect(settings.previewCollapsed, false);
      expect(settings.logsPanelWidth, 640);
    });

    test('fromJson uses defaults for missing preview keys', () {
      final legacy = AppSettings.fromJson({
        'patrolPath': 'patrol',
        'rightPanelWidth': 400,
        'logsPanelWidth': 640,
      });
      expect(legacy.previewPanelWidth, 390);
      expect(legacy.previewCollapsed, false);
      expect(legacy.logsPanelWidth, 640);
    });

    test('resetLayoutDefaults restores all panel visibility', () {
      final collapsed = AppSettings.defaults().copyWith(
        previewCollapsed: true,
        logsCollapsed: true,
        rightCollapsed: true,
        previewPanelWidth: 300,
        logsPanelWidth: 900,
        rightPanelWidth: 500,
      );
      final reset = AppSettings.resetLayoutDefaults(collapsed);
      expect(reset.previewCollapsed, false);
      expect(reset.logsCollapsed, false);
      expect(reset.rightCollapsed, false);
      expect(reset.previewPanelWidth, 390);
      expect(reset.logsPanelWidth, 640);
      expect(reset.rightPanelWidth, 380);
    });

    test('round-trip preserves preview settings', () {
      final original = AppSettings.defaults().copyWith(
        previewPanelWidth: 420,
        previewCollapsed: true,
        logsPanelWidth: 500,
      );
      final restored = AppSettings.fromJson(original.toJson());
      expect(restored.previewPanelWidth, 420);
      expect(restored.previewCollapsed, true);
      expect(restored.logsPanelWidth, 500);
    });
  });
}