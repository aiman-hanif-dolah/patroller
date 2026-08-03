import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/domain/log_classification.dart';
import 'package:patroller/domain/log_sanitizer.dart';
import 'package:patroller/models/enums.dart';
import 'package:patroller/models/run_record.dart';

LogEvent _log(
  String text, {
  LogStreamType stream = LogStreamType.stdout,
  LogSource source = LogSource.flutter,
}) {
  return LogEvent(
    runId: 'run-1',
    streamType: stream,
    timestamp: '2026-01-01T00:00:00Z',
    text: text,
    lineNumber: 1,
    source: source,
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

    test('routine informational lines are Routine, not Error', () {
      expect(
        classifyLog(
          _log(
            '── Autonomous Patrol routine started ──',
            stream: LogStreamType.stdout,
            source: LogSource.system,
          ),
        ),
        LogCategory.routine,
      );
      expect(
        classifyLog(
          _log(
            '[routine] [started] OpenCode routine started with model on device',
            stream: LogStreamType.stdout,
            source: LogSource.system,
          ),
        ),
        LogCategory.routine,
      );
      expect(
        classifyLog(
          _log(
            '[routine] [debug_session] Automated Flutter debug session launched',
            stream: LogStreamType.stdout,
            source: LogSource.system,
          ),
        ),
        LogCategory.routine,
      );
      // Regression: even when emitted on stderr (legacy appendSystemLog),
      // informational routine lines must not become Error.
      expect(
        classifyLog(
          _log(
            '── Autonomous Patrol routine started ──',
            stream: LogStreamType.stderr,
            source: LogSource.system,
          ),
        ),
        LogCategory.routine,
      );
    });

    test('routine failure kinds remain Error', () {
      expect(
        classifyLog(
          _log(
            '[routine] [failed] OpenCode routine finished with failures',
            stream: LogStreamType.stderr,
            source: LogSource.system,
          ),
        ),
        LogCategory.error,
      );
      expect(
        classifyLog(
          _log(
            '[routine] [needsAttention] Readiness is blocked',
            source: LogSource.system,
          ),
        ),
        LogCategory.error,
      );
    });
  });

  group('groupDependencyNotices', () {
    test('collapses consecutive dependency notices into one block', () {
      final logs = [
        LogEvent(
          runId: 'r1',
          streamType: LogStreamType.stdout,
          timestamp: '2026-01-01T00:00:00Z',
          text: 'Resolving dependencies...',
          lineNumber: 1,
          source: LogSource.system,
        ),
        LogEvent(
          runId: 'r1',
          streamType: LogStreamType.stdout,
          timestamp: '2026-01-01T00:00:01Z',
          text: 'Got dependencies!',
          lineNumber: 2,
          source: LogSource.system,
        ),
      ];
      final grouped = groupDependencyNotices(logs);
      expect(grouped.length, 1);
      expect(isDependencyNoticeBlock(grouped.first), isTrue);
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

  group('getLogFilterKey', () {
    test('returns routine filter key for routine logs', () {
      final log = _log(
        '[routine] [started] OpenCode routine started',
        source: LogSource.routine,
      );
      expect(getLogFilterKey(log), LogFilterKey.routine);
    });
  });
}