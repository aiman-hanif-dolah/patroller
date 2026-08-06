import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/services/crash_service.dart';

void main() {
  group('CrashService tests', () {
    tearDown(() {
      CrashService.instance.clearCrashReport();
    });

    test('records and retrieves crash report correctly', () {
      expect(CrashService.instance.hasPendingCrashReport(), false);

      CrashService.instance.recordCrash(
        error: 'Test exception: RangeError (index)',
        stackTrace: '#0 main (package:patroller/main.dart:10)',
        library: 'flutter test',
        context: 'while building widget',
      );

      expect(CrashService.instance.hasPendingCrashReport(), true);

      final report = CrashService.instance.getLatestCrashReport();
      expect(report, isNotNull);
      expect(report!.error, contains('Test exception'));
      expect(report.stackTrace, contains('package:patroller/main.dart'));
      expect(report.library, equals('flutter test'));
      expect(report.context, equals('while building widget'));

      final formatted = report.toFormattedString();
      expect(formatted, contains('PATROLLER CRASH REPORT'));
      expect(formatted, contains('Test exception: RangeError'));
    });

    test('clears crash report on command', () {
      CrashService.instance.recordCrash(
        error: 'Fatal error',
        stackTrace: 'stacktrace text',
      );

      expect(CrashService.instance.hasPendingCrashReport(), true);
      CrashService.instance.clearCrashReport();
      expect(CrashService.instance.hasPendingCrashReport(), false);
      expect(CrashService.instance.getLatestCrashReport(), isNull);
    });
  });
}
