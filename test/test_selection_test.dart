import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/domain/runner_helpers.dart';
import 'package:patroller/models/device_info.dart';
import 'package:patroller/models/enums.dart';
import 'package:patroller/models/test_file.dart';

TestFile _file(String path, int testCount) {
  return TestFile(
    absolutePath: '/project/$path',
    relativePath: path,
    fileName: path.split('/').last,
    folderPath: '',
    fileSize: 100,
    lastModified: '2026-01-01',
    detectedTestCount: testCount,
    detectedGroups: const [],
    detectedTests: const [],
    lastRunStatus: TestStatus.idle,
  );
}

TestFile _flowFile(String folder, String name, {int testCount = 1}) {
  return TestFile(
    absolutePath: '/project/patrol_test/$folder/$name',
    relativePath: 'patrol_test/$folder/$name',
    fileName: name,
    folderPath: folder,
    fileSize: 100,
    lastModified: '2026-01-01',
    detectedTestCount: testCount,
    detectedGroups: const [],
    detectedTests: const [],
    lastRunStatus: TestStatus.idle,
  );
}

void main() {
  group('Test All selection', () {
    test('runnableTestFiles excludes 0-test helper files', () {
      final files = [
        _file('patrol_test/a_test.dart', 2),
        _file('patrol_test/helpers.dart', 0),
      ];
      final runnable = runnableTestFiles(files);
      expect(runnable.length, 1);
      expect(runnable.first.fileName, 'a_test.dart');
    });

    test('helper files are identifiable', () {
      expect(isHelperTestFile(_file('helpers.dart', 0)), true);
      expect(isRunnableTestFile(_file('a_test.dart', 1)), true);
    });

    test('selection banner uses checked wording (not Test All)', () {
      expect(formatTestAllSelectionBanner(0), 'No files checked');
      expect(formatTestAllSelectionBanner(2), '2 files checked');
    });

    test('Test All badge reflects flow scope', () {
      expect(
        describeTestAllQueueBadge(
          flowFilter: kAllFlowsFilter,
          queueFileCount: 5,
        ).value,
        'All runnable',
      );
      expect(
        describeTestAllQueueBadge(
          flowFilter: 'auth',
          queueFileCount: 1,
        ).value,
        'auth · 1 file',
      );
      expect(
        describeTestAllQueueBadge(
          flowFilter: 'auth',
          queueFileCount: 3,
        ).value,
        'auth · 3 files',
      );
    });

    test('filesForRunAll with all-flows yields every runnable file', () {
      final files = [
        _flowFile('auth', 'login_test.dart'),
        _flowFile('auth', 'logout_test.dart'),
        _flowFile('settings', 'theme_test.dart'),
        _flowFile('auth', 'helpers.dart', testCount: 0),
      ];
      final result = filesForRunAll(files, kAllFlowsFilter);
      expect(result.map((f) => f.fileName).toList(), [
        'login_test.dart',
        'logout_test.dart',
        'theme_test.dart',
      ]);
    });

    test('filesForRunAll with concrete flow yields all runnable in flow', () {
      final files = [
        _flowFile('auth', 'login_test.dart'),
        _flowFile('auth', 'logout_test.dart'),
        _flowFile('settings', 'theme_test.dart'),
        _flowFile('auth', 'helpers.dart', testCount: 0),
      ];
      final result = filesForRunAll(files, 'auth');
      expect(result.map((f) => f.fileName).toList(), [
        'login_test.dart',
        'logout_test.dart',
      ]);
    });

    test('filesForRunAll ignores individual checkbox selection', () {
      // Even if only one auth file would be checked in the UI, Test All for
      // the auth flow still queues every runnable auth file.
      final files = [
        _flowFile('auth', 'login_test.dart'),
        _flowFile('auth', 'logout_test.dart'),
        _flowFile('settings', 'theme_test.dart'),
      ];
      final result = filesForRunAll(files, 'auth');
      expect(result.length, 2);
      expect(result.every((f) => f.folderPath.startsWith('auth')), isTrue);
    });

    test('Test / Test All tooltips describe flow rules', () {
      expect(
        testButtonTooltip(willBootSimulator: false),
        'Run the selected test file only.',
      );
      expect(
        testButtonTooltip(willBootSimulator: true),
        'Run the selected test file only (will boot simulator if needed).',
      );
      expect(
        testAllButtonTooltip(kAllFlowsFilter),
        'Run all runnable test files in the project.',
      );
      expect(
        testAllButtonTooltip('auth'),
        'Run all files in the auth flow.',
      );
    });
  });

  group('getRunDisabledReason', () {
    DeviceInfo sim({DeviceState state = DeviceState.shutdown}) {
      return DeviceInfo(
        id: 'udid-1',
        name: 'iPhone',
        type: DeviceType.iosSimulator,
        state: state,
        platform: 'ios',
        availability: 'available',
        rawLine: 'iPhone',
      );
    }

    test('allows run when simulator is not yet booted', () {
      expect(
        getRunDisabledReason(
          hasProject: true,
          hasSelectedFile: true,
          isRunning: false,
          selectedDevice: sim(),
          currentRun: null,
        ),
        isNull,
      );
    });

    test('blocks when no file selected', () {
      expect(
        getRunDisabledReason(
          hasProject: true,
          hasSelectedFile: false,
          isRunning: false,
          selectedDevice: sim(state: DeviceState.booted),
          currentRun: null,
        ),
        'Choose a test file first',
      );
    });
  });

  group('All flows selection', () {
    test('sentinel selects all files after a concrete flow filter', () {
      final files = [
        _flowFile('account', 'login_test.dart'),
        _flowFile('account', 'signup_test.dart'),
        _flowFile('account', 'profile_test.dart'),
        _flowFile('account', 'logout_test.dart'),
        _flowFile('settings', 'theme_test.dart'),
        _flowFile('settings', 'locale_test.dart'),
      ];

      final accountOnly = selectedFileIdsForFlowFilter(files, 'account');
      expect(accountOnly.length, 4);

      final allFlows = selectedFileIdsForFlowFilter(files, kAllFlowsFilter);
      expect(allFlows.length, files.length);
      expect(allFlows, files.map((f) => f.absolutePath).toSet());
    });

    test('concrete flow selects only matching folderPath prefix', () {
      final files = [
        _flowFile('account', 'login_test.dart'),
        _flowFile('settings', 'theme_test.dart'),
      ];
      final ids = selectedFileIdsForFlowFilter(files, 'settings');
      expect(ids, {'/project/patrol_test/settings/theme_test.dart'});
      expect(isAllFlowsFilter(kAllFlowsFilter), isTrue);
      expect(isAllFlowsFilter('account'), isFalse);
    });
  });
}
