import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/domain/settings_validation.dart';
import 'package:patroller/models/app_settings.dart';

void main() {
  group('validateAppSettings', () {
    test('rejects empty CLI paths', () {
      final settings = AppSettings.defaults().copyWith(patrolPath: '  ');
      final errors = validateAppSettings(settings);
      expect(
        errors.any((error) => error.field == 'patrolPath'),
        isTrue,
      );
    });

    test('rejects logs width outside allowed range', () {
      final settings = AppSettings.defaults().copyWith(logsPanelWidth: 40);
      final errors = validateAppSettings(settings);
      expect(
        errors.any((error) => error.field == 'logsPanelWidth'),
        isTrue,
      );
    });
  });

  group('parsePositiveInt', () {
    test('accepts values inside range', () {
      expect(parsePositiveInt('390', min: 280, max: 720), 390);
    });

    test('rejects out-of-range values', () {
      expect(parsePositiveInt('9999', min: 280, max: 720), isNull);
    });
  });
}