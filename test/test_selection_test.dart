import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/domain/runner_helpers.dart';
import 'package:patroller/models/test_file.dart';
import 'package:patroller/models/enums.dart';

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
  });
}