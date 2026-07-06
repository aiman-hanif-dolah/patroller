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
}