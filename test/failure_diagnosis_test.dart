import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/domain/failure_diagnosis.dart';

void main() {
  group('diagnosePatrolFailure', () {
    test('detects assertion Expected/Actual', () {
      const log = '''
[stderr] ── Test All 2/2: smoke_test.dart ──
[stdout] Expected: '999'
[stdout]   Actual: '0'
[stdout] EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK
[stdout] TestFailure was thrown
''';
      final d = diagnosePatrolFailure(log);
      expect(d, isNotNull);
      expect(d!.category, FailureCategory.assertion);
      expect(d.title, contains('assertion'));
      expect(d.summary, contains('999'));
      expect(d.summary, contains('0'));
    });

    test('detects xcodebuild code 70 as missing iOS host', () {
      const log = '''
Total: 0
xcodebuild exited with code 70
''';
      final d = diagnosePatrolFailure(log);
      expect(d, isNotNull);
      expect(d!.category, FailureCategory.projectSetup);
      expect(d.title.toLowerCase(), contains('ios'));
    });

    test('detects missing patrol cli', () {
      final d = diagnosePatrolFailure('command not found: patrol');
      expect(d, isNotNull);
      expect(d!.copyCommand, contains('patrol_cli'));
      expect(d.category, FailureCategory.tooling);
    });

    test('detects iOS simulator requirement', () {
      final d = diagnosePatrolFailure('Select an iOS Simulator to run tests');
      expect(d, isNotNull);
      expect(d!.category, FailureCategory.device);
    });

    test('detects stale develop hot-restart during patrol test', () {
      const log = '''
📝   All tests were executed. Press "r" to start again or "q" to quit
Test summary:
✅ Successful: 4
❌ Failed: 0
xcodebuild exited with code 65
''';
      final d = diagnosePatrolFailure(log);
      expect(d, isNotNull);
      expect(d!.title.toLowerCase(), contains('hot-restart'));
      expect(d.category, FailureCategory.build);
      expect(d.likelyFix.toLowerCase(), contains('patrol_hot_restart'));
    });

    test('returns null for empty noise', () {
      expect(diagnosePatrolFailure(''), isNull);
      expect(diagnosePatrolFailure('Building app...'), isNull);
    });
  });
}
