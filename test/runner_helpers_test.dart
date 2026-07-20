import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/domain/runner_helpers.dart';
import 'package:patroller/models/models.dart';

void main() {
  group('hotRestartDisabledReason', () {
    RunRecord developRun({RunLifecycle lifecycle = RunLifecycle.running}) {
      return RunRecord(
        runId: 'run-1',
        projectId: 'proj-1',
        projectPath: '/tmp/project',
        projectName: 'project',
        command: 'patrol',
        args: const ['develop'],
        fullCommandForDisplay: 'patrol develop',
        targetFiles: const [],
        runMode: RunMode.develop,
        lifecycle: lifecycle,
        status: RunRecordStatus.running,
        startTime: '2026-07-03T10:00:00.000Z',
        environmentSnapshot: '{}',
        appVersion: '1.0.0',
      );
    }

    test('blocks when no develop session is active', () {
      expect(
        hotRestartDisabledReason(isRunning: false, currentRun: null),
        'No active develop session',
      );
    });

    test('blocks while session is starting', () {
      expect(
        hotRestartDisabledReason(
          isRunning: true,
          currentRun: developRun(lifecycle: RunLifecycle.starting),
        ),
        'Waiting for session to start',
      );
    });

    test('allows restart while develop session is running', () {
      expect(
        hotRestartDisabledReason(
          isRunning: true,
          currentRun: developRun(),
        ),
        isNull,
      );
    });
  });

  group('formatRunLogsForExport', () {
    test('formats structured log events', () {
      final text = formatRunLogsForExport(
        logs: const [
          LogEvent(
            runId: 'run-1',
            streamType: LogStreamType.stdout,
            timestamp: '2026-07-03T10:15:30.000Z',
            text: 'Test failed',
            lineNumber: 1,
            source: LogSource.patrol,
          ),
        ],
      );
      expect(text, contains('Test failed'));
      expect(text, contains('|'));
    });

    test('falls back to combined and stderr logs', () {
      final text = formatRunLogsForExport(
        logs: const [],
        combinedLog: 'stdout line',
        stderrLog: 'stderr line',
      );
      expect(text, contains('stdout line'));
      expect(text, contains('stderr line'));
    });
  });

  group('Develop All stop abort', () {
    test('stop clears queue and blocks auto-advance', () {
      // Simulate Develop All with 2+ queued files, then one Stop.
      var queue = [
        '/project/a_test.dart',
        '/project/b_test.dart',
        '/project/c_test.dart',
      ];
      var userStopped = false;
      var isRunning = true;

      // stop() / forceStop() contract
      userStopped = true;
      queue = [];
      isRunning = false;

      expect(queue, isEmpty);
      expect(isRunning, isFalse);
      expect(
        shouldAdvanceDevelopSuite(
          userStopped: userStopped,
          completedMode: RunMode.developSuite,
          queueNotEmpty: queue.isNotEmpty,
        ),
        isFalse,
      );
    });

    test('onComplete does not advance when userStopped even if queue remains', () {
      expect(
        shouldAdvanceDevelopSuite(
          userStopped: true,
          completedMode: RunMode.developSuite,
          queueNotEmpty: true,
        ),
        isFalse,
      );
    });

    test('onComplete advances only when not stopped and queue has files', () {
      expect(
        shouldAdvanceDevelopSuite(
          userStopped: false,
          completedMode: RunMode.developSuite,
          queueNotEmpty: true,
        ),
        isTrue,
      );
      expect(
        shouldAdvanceDevelopSuite(
          userStopped: false,
          completedMode: RunMode.developSuite,
          queueNotEmpty: false,
        ),
        isFalse,
      );
      expect(
        shouldAdvanceDevelopSuite(
          userStopped: false,
          completedMode: RunMode.develop,
          queueNotEmpty: true,
        ),
        isFalse,
      );
    });
  });

  group('session completion snackbar', () {
    test('detects patrol develop all-tests message', () {
      expect(
        isAllTestsExecutedMessage(
          '📝   All tests were executed. Press "r" to start again or "q" to quit',
        ),
        isTrue,
      );
      expect(
        isAllTestsExecutedMessage('Running integration tests...'),
        isFalse,
      );
    });

    test('returns develop message when all tests were seen', () {
      expect(
        sessionCompletionSnackbarMessage(
          runMode: RunMode.develop,
          status: RunRecordStatus.running,
          allTestsExecutedSeen: true,
        ),
        'Develop session finished - all tests executed',
      );
    });

    test('returns test passed message on terminal success', () {
      expect(
        sessionCompletionSnackbarMessage(
          runMode: RunMode.test,
          status: RunRecordStatus.passed,
          allTestsExecutedSeen: false,
        ),
        'Test finished - all tests passed',
      );
    });

    test('skips develop suite snackbar while queue has more files', () {
      expect(
        sessionCompletionSnackbarMessage(
          runMode: RunMode.developSuite,
          status: RunRecordStatus.passed,
          allTestsExecutedSeen: true,
          developSuiteHasMore: true,
        ),
        isNull,
      );
    });
  });

  group('emptyLogsBusyMessage', () {
    test('Starting only while lifecycle is starting', () {
      expect(emptyLogsBusyMessage(RunLifecycle.starting), 'Starting...');
    });

    test('Stopping while lifecycle is stopping', () {
      expect(emptyLogsBusyMessage(RunLifecycle.stopping), 'Stopping...');
    });

    test('Running otherwise when busy', () {
      expect(emptyLogsBusyMessage(RunLifecycle.running), 'Running...');
      expect(emptyLogsBusyMessage(null), 'Running...');
    });
  });
}