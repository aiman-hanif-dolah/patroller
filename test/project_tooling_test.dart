import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:patroller/services/project_tooling_service.dart';

void main() {
  test('parses direct and dev dependencies without nested entries', () {
    const yaml = '''
name: demo
dependencies:
  flutter:
    sdk: flutter
  marionette_flutter: ^0.6.0
dev_dependencies:
  patrol: ^4.7.0
  integration_test:
    sdk: flutter
''';

    final dependencies = ProjectToolingService().parseDependencies(yaml);

    expect(dependencies.map((dependency) => dependency.name), [
      'flutter',
      'marionette_flutter',
      'patrol',
      'integration_test',
    ]);
    expect(
      dependencies
          .firstWhere((dependency) => dependency.name == 'patrol')
          .isDev,
      isTrue,
    );
  });

  test('findEntrypoint returns unambiguous main.dart candidate', () {
    final tempDir = Directory.systemTemp.createTempSync('patroller_entrypoint_test_');
    try {
      final libDir = Directory(p.join(tempDir.path, 'lib'))..createSync();
      File(p.join(libDir.path, 'main.dart')).writeAsStringSync('void main() {}');

      final entrypoint = ProjectToolingService().findEntrypoint(tempDir.path);
      expect(entrypoint, 'lib/main.dart');
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('setupNativePatrolHost creates missing iOS and Android native runner files', () async {
    final tempDir = Directory.systemTemp.createTempSync('patroller_native_host_test_');
    try {
      final result = await ProjectToolingService().setupNativePatrolHost(tempDir.path);
      expect(result.ok, isTrue);

      final swiftFile = File(p.join(tempDir.path, 'ios', 'RunnerTests', 'RunnerTests.swift'));
      final androidFile = File(
        p.join(tempDir.path, 'android', 'app', 'src', 'androidTest', 'java', 'com', 'example', 'app', 'MainActivityTest.kt'),
      );
      expect(swiftFile.existsSync(), isTrue);
      expect(androidFile.existsSync(), isTrue);
      expect(swiftFile.readAsStringSync(), contains('PatrolJUnitTestRunner'));
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('inspect classifies non-flutter directory as blocked', () async {
    final tempDir = Directory.systemTemp.createTempSync('patroller_inspect_blocked_');
    try {
      final report = await ProjectToolingService().inspect(projectPath: tempDir.path);
      expect(report.ok, isFalse);
      expect(report.status.name, 'blocked');
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });
}
