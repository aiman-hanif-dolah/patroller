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

    test('selection banner uses selected wording', () {
      expect(formatTestAllSelectionBanner(0), 'All runnable files');
      expect(formatTestAllSelectionBanner(2), '2 files selected for Test All');
    });

    test('Test All badge uses file(s) selected wording', () {
      expect(describeTestAllQueueBadge(0).value, 'All runnable');
      expect(describeTestAllQueueBadge(1).value, '1 file selected');
      expect(describeTestAllQueueBadge(2).value, '2 files selected');
    });

    test('filesForRunAll uses multi-select when set', () {
      final files = [
        _file('patrol_test/a_test.dart', 1),
        _file('patrol_test/b_test.dart', 1),
        _file('patrol_test/helpers.dart', 0),
      ];
      final selected = {'/project/patrol_test/b_test.dart'};
      final result = filesForRunAll(files, selected);
      expect(result.length, 1);
      expect(result.first.fileName, 'b_test.dart');
    });

    test('filesForRunAll falls back to all runnable when selection empty', () {
      final files = [
        _file('patrol_test/a_test.dart', 1),
        _file('patrol_test/b_test.dart', 2),
      ];
      final result = filesForRunAll(files, {});
      expect(result.length, 2);
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
    TestFile flowFile(String folder, String name) {
      return TestFile(
        absolutePath: '/project/patrol_test/$folder/$name',
        relativePath: 'patrol_test/$folder/$name',
        fileName: name,
        folderPath: folder,
        fileSize: 100,
        lastModified: '2026-01-01',
        detectedTestCount: 1,
        detectedGroups: const [],
        detectedTests: const [],
        lastRunStatus: TestStatus.idle,
      );
    }

    test('sentinel selects all files after a concrete flow filter', () {
      final files = [
        flowFile('account', 'login_test.dart'),
        flowFile('account', 'signup_test.dart'),
        flowFile('account', 'profile_test.dart'),
        flowFile('account', 'logout_test.dart'),
        flowFile('settings', 'theme_test.dart'),
        flowFile('settings', 'locale_test.dart'),
      ];

      final accountOnly = selectedFileIdsForFlowFilter(files, 'account');
      expect(accountOnly.length, 4);

      final allFlows = selectedFileIdsForFlowFilter(files, kAllFlowsFilter);
      expect(allFlows.length, files.length);
      expect(allFlows, files.map((f) => f.absolutePath).toSet());
    });

    test('concrete flow selects only matching folderPath prefix', () {
      final files = [
        flowFile('account', 'login_test.dart'),
        flowFile('settings', 'theme_test.dart'),
      ];
      final ids = selectedFileIdsForFlowFilter(files, 'settings');
      expect(ids, {'/project/patrol_test/settings/theme_test.dart'});
      expect(isAllFlowsFilter(kAllFlowsFilter), isTrue);
      expect(isAllFlowsFilter('account'), isFalse);
    });
  });
}