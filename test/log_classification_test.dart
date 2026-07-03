import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/domain/log_classification.dart';
import 'package:patroller/domain/log_sanitizer.dart';
import 'package:patroller/models/enums.dart';
import 'package:patroller/models/run_record.dart';

LogEvent _log(String text, {LogStreamType stream = LogStreamType.stdout}) {
  return LogEvent(
    runId: 'run-1',
    streamType: stream,
    timestamp: '2026-01-01T00:00:00Z',
    text: text,
    lineNumber: 1,
    source: LogSource.flutter,
  );
}

void main() {
  group('sanitizeLogText', () {
    test('removes ANSI sequences', () {
      expect(
        sanitizeLogText('\x1B[31mFAILED\x1B[0m'),
        'FAILED',
      );
    });
  });

  group('classifyLog', () {
    test('SPM and dependency output becomes warning', () {
      expect(
        classifyLog(_log('Resolving dependencies in pubspec.yaml...')),
        LogCategory.warning,
      );
      expect(
        classifyLog(_log('Running pod install in ios folder')),
        LogCategory.warning,
      );
    });

    test('actual patrol failure remains error', () {
      expect(
        classifyLog(_log('Patrol test failed: assertion failed')),
        LogCategory.error,
      );
      expect(
        classifyLog(_log('Test failed: expected: true actual: false')),
        LogCategory.error,
      );
    });
  });

  group('collapseRepeatedLogBlocks', () {
    test('collapses repeated flutter warning blocks', () {
      final logs = List.generate(
        4,
        (i) => _log('Resolving dependencies attempt $i'),
      );
      final collapsed = collapseRepeatedLogBlocks(logs);
      expect(collapsed.length, 3);
      expect(collapsed[1].text, contains('collapsed'));
    });
  });
}