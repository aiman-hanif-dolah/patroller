import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/domain/report/html_report_generator.dart';
import 'package:patroller/domain/report/patrol_log_parser.dart';
import 'package:patroller/domain/report/report_aggregator.dart';
import 'package:patroller/domain/report/report_models.dart';
import 'package:patroller/models/enums.dart';
import 'package:patroller/models/run_record.dart';

void main() {
  group('PatrolLogParser', () {
    final parser = PatrolLogParser();

    test('parses runDartTest PASSED/FAILED lines', () {
      const log = '''
runDartTest("suite.home_suite_test Home shell loads"): call finished, test result: PASSED
runDartTest("suite.home_suite_test Authorized user can round-trip bottom navigation"): call finished, test result: FAILED
''';
      final scenarios = parser.parseScenarios(log, suiteOrTarget: 'home');
      expect(scenarios, hasLength(2));
      expect(scenarios[0].name, 'Home shell loads');
      expect(scenarios[0].status, ScenarioStatus.passed);
      expect(scenarios[1].status, ScenarioStatus.failed);
    });

    test('parses Successful/Failed suite counts', () {
      const log = '''
** TEST EXECUTE SUCCEEDED **
✅ Successful: 34
❌ Failed: 0
''';
      final counts = parser.parseSuiteCounts(log);
      expect(counts?.passed, 34);
      expect(counts?.failed, 0);
    });

    test('parses emoji result fallback', () {
      const log = '''
✅ Guest user can continue from TNC screen to Home shell (/suite/auth_suite_test.dart) (13s)
❌ Authorized user can round-trip bottom navigation (/suite/home_suite_test.dart) (18s)
''';
      final scenarios = parser.parseScenarios(log);
      expect(scenarios, hasLength(2));
      expect(scenarios.first.isPassed, isTrue);
      expect(scenarios.last.isFailed, isTrue);
    });

    test('parses patrol_cli leaf emoji results and last Test summary counts', () {
      const log = '''
✅ counter starts at zero (/counter_test.dart) (0s)
✅ increment FAB can be found by icon and tooltip (/counter_test.dart) (0s)
✅ tapping increment FAB increases counter by one (/counter_test.dart) (0s)
        ✅   1. tap widgets with key [<'increment_fab'>].
Test summary:
📝 Total: 5
✅ Successful: 5
❌ Failed: 0
''';
      final scenarios = parser.parseScenarios(log);
      expect(scenarios.length, greaterThanOrEqualTo(3));
      expect(scenarios.every((s) => s.isPassed), isTrue);
      // step ticks must not be counted as scenarios
      expect(scenarios.any((s) => s.name.startsWith('1.')), isFalse);

      final counts = parser.parseSuiteCounts(log);
      expect(counts?.passed, 5);
      expect(counts?.failed, 0);
    });

    test('uses last Test summary when log has multiple blocks', () {
      const log = '''
Test summary:
📝 Total: 99
✅ Successful: 90
❌ Failed: 9
Test summary:
📝 Total: 2
✅ Successful: 2
❌ Failed: 0
''';
      final counts = parser.parseSuiteCounts(log);
      expect(counts?.passed, 2);
      expect(counts?.failed, 0);
    });

    test('strips ANSI color codes around paths', () {
      const log =
          '❌ app launches and native home press works \x1b[90m(/smoke_test.dart)\x1b[0m \x1b[90m(0s)\x1b[0m\n'
          '✅ counter starts at zero \x1b[90m(/counter_test.dart)\x1b[0m \x1b[90m(0s)\x1b[0m\n'
          'Test summary:\n'
          '📝 Total: 2\n'
          '✅ Successful: 1\n'
          '❌ Failed: 1\n';
      final scenarios = parser.parseScenarios(log);
      expect(scenarios, hasLength(2));
      expect(scenarios.any((s) => s.isFailed && s.name.contains('app launches')),
          isTrue);
      expect(scenarios.any((s) => s.isPassed && s.name.contains('counter starts')),
          isTrue);
      final counts = parser.parseSuiteCounts(log);
      expect(counts?.passed, 1);
      expect(counts?.failed, 1);
    });
  });

  group('ReportAggregator + HtmlReportGenerator', () {
    test('builds report from RunRecords and renders HTML', () {
      final record = RunRecord(
        runId: 'run_1',
        projectId: 'proj',
        projectPath: '/tmp/demo-app',
        projectName: 'demo-app',
        command: 'patrol',
        args: const ['test'],
        fullCommandForDisplay: 'patrol test -t patrol_test/suite/smoke.dart',
        targetFile: '/tmp/demo-app/patrol_test/suite/smoke_suite_test.dart',
        targetFiles: const [],
        runMode: RunMode.test,
        selectedDevice: 'iPhone 17',
        startTime: DateTime.now().toUtc().toIso8601String(),
        status: RunRecordStatus.passed,
        environmentSnapshot: '',
        appVersion: '1.0.0',
        combinedLog: '''
runDartTest("suite.smoke_suite_test Authorized user in home page"): call finished, test result: PASSED
runDartTest("suite.smoke_suite_test Home Page shows error state when config fails to load"): call finished, test result: PASSED
** TEST EXECUTE SUCCEEDED **
✅ Successful: 2
❌ Failed: 0
''',
      );

      final report = ReportAggregator().fromRunRecords(
        projectPath: '/tmp/demo-app',
        projectName: 'demo-app',
        records: [record],
        leafRelativePaths: const [
          'patrol_test/homecontainer/smoke/authorized_user_home_page_test.dart',
          'patrol_test/homecontainer/smoke/home_config_error_state_test.dart',
        ],
        declaredNamesByRelativePath: const {
          'patrol_test/homecontainer/smoke/authorized_user_home_page_test.dart':
              ['Authorized user in home page'],
          'patrol_test/homecontainer/smoke/home_config_error_state_test.dart': [
            'Home Page shows error state when config fails to load',
          ],
        },
        device: 'iPhone 17',
        runMode: 'test',
        queueLabel: 'Batch of 1',
      );

      expect(report.targets, hasLength(1));
      expect(report.targets.first.passed, 2);
      expect(report.targets.first.failed, 0);
      expect(report.scenarioPassed, 2);
      expect(report.scenarioFailed, 0);

      final html = const HtmlReportGenerator().generate(report);
      expect(html, contains('demo-app'));
      expect(html, contains('ALL GREEN'));
      expect(html, contains('Authorized user in home page'));
      expect(html, contains('Patroller'));
    });
  });
}
