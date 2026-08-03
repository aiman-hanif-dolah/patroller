import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/domain/patrol_run_outcome.dart';

void main() {
  group('patrolTestModeDartDefineArgs', () {
    test('disables hot restart for test mode', () {
      expect(
        patrolTestModeDartDefineArgs(),
        ['--dart-define', 'PATROL_HOT_RESTART=false'],
      );
      expect(patrolHotRestartOffDefine, 'PATROL_HOT_RESTART=false');
    });
  });

  group('isStaleHotRestartTestFailure', () {
    const contaminatedLog = '''
✅ home screen shows initial counter state (/counter_test.dart) (0s)
📝   All tests were executed. Press "r" to start again or "q" to quit
Test summary:
📝 Total: 13
✅ Successful: 4
❌ Failed: 0
⏩ Skipped: 0
✗ Failed to execute tests of app with entrypoint test_bundle.dart (xcodebuild exited with code 65)
Error: xcodebuild exited with code 65
''';

    test('detects develop wait + Failed: 0 + xcodebuild 65', () {
      expect(isStaleHotRestartTestFailure(contaminatedLog), isTrue);
      expect(hasDevelopHotRestartWaitMessage(contaminatedLog), isTrue);
      expect(hasXcodebuildExit65(contaminatedLog), isTrue);
    });

    test('does not treat real assertion failures as hot-restart contamination', () {
      const assertionLog = '''
Expected: '1'
  Actual: '0'
TestFailure was thrown
xcodebuild exited with code 65
''';
      expect(isStaleHotRestartTestFailure(assertionLog), isFalse);
    });

    test('does not match when Failed count is non-zero', () {
      const failedLog = '''
📝   All tests were executed. Press "r" to start again or "q" to quit
Test summary:
✅ Successful: 2
❌ Failed: 1
xcodebuild exited with code 65
''';
      expect(isStaleHotRestartTestFailure(failedLog), isFalse);
    });

    test('does not match plain xcodebuild 65 without develop wait', () {
      expect(
        isStaleHotRestartTestFailure('xcodebuild exited with code 65'),
        isFalse,
      );
    });
  });
}
