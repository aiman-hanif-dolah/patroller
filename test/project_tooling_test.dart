import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:patroller/domain/routine_models.dart';
import 'package:patroller/services/project_tooling_service.dart';

void main() {
  test('parses direct, SDK map, and inline SDK dependencies', () {
    const yaml = '''
name: demo
dependencies:
  flutter:
    sdk: flutter
  marionette_flutter: ^0.6.0
  cupertino_icons: { sdk: flutter }
dev_dependencies:
  patrol: ^4.7.0
  integration_test:
    sdk: flutter
''';

    final dependencies = ProjectToolingService().parseDependencies(yaml);

    expect(dependencies.map((dependency) => dependency.name), [
      'flutter',
      'marionette_flutter',
      'cupertino_icons',
      'patrol',
      'integration_test',
    ]);
    expect(
      dependencies
          .firstWhere((dependency) => dependency.name == 'patrol')
          .isDev,
      isTrue,
    );
    final integration = dependencies.firstWhere(
      (dependency) => dependency.name == 'integration_test',
    );
    expect(integration.isDev, isTrue);
    expect(integration.isFlutterSdk, isTrue);
    expect(integration.source, 'sdk');
    expect(
      dependencies
          .firstWhere((dependency) => dependency.name == 'flutter')
          .isFlutterSdk,
      isTrue,
    );
    expect(
      dependencies
          .firstWhere((dependency) => dependency.name == 'cupertino_icons')
          .isFlutterSdk,
      isTrue,
    );
  });

  test('detects malformed integration_test version constraints as non-SDK', () {
    const yaml = '''
name: demo
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  integration_test: any
''';

    final dependencies = ProjectToolingService().parseDependencies(yaml);
    final integration = dependencies.singleWhere(
      (dependency) => dependency.name == 'integration_test',
    );
    expect(integration.constraint, 'any');
    expect(integration.isFlutterSdk, isFalse);
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
      expect(report.canStartPrepare, isFalse);
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('inspect marks missing or malformed integration_test as repairable', () async {
    final tempDir = Directory.systemTemp.createTempSync('patroller_inspect_integration_');
    try {
      File(p.join(tempDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: demo
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  integration_test: any
''');
      Directory(p.join(tempDir.path, 'lib')).createSync();
      File(p.join(tempDir.path, 'lib', 'main.dart')).writeAsStringSync('void main() {}');

      final report = await ProjectToolingService().inspect(projectPath: tempDir.path);
      final integration = report.checks.singleWhere(
        (check) => check.id == 'integration_test',
      );
      expect(integration.ok, isFalse);
      expect(integration.repairable, isTrue);
      expect(integration.fixCommand, contains('--sdk=flutter'));
      expect(report.canStartPrepare, isTrue);
      expect(report.status, isNot(RoutineReadiness.blocked));
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('patrolSweepArgs includes -d when device is set', () {
    expect(
      ProjectToolingService.patrolSweepArgs(),
      ['test', '--dart-define', 'PATROL_HOT_RESTART=false'],
    );
    expect(
      ProjectToolingService.patrolSweepArgs(device: '  '),
      ['test', '--dart-define', 'PATROL_HOT_RESTART=false'],
    );
    expect(
      ProjectToolingService.patrolSweepArgs(device: 'SIM-UDID'),
      [
        'test',
        '--dart-define',
        'PATROL_HOT_RESTART=false',
        '-d',
        'SIM-UDID',
      ],
    );
  });

  test('runPatrolSweep allowEmpty treats missing/empty suite as ok', () async {
    final tempDir = Directory.systemTemp.createTempSync('patroller_empty_sweep_');
    try {
      final tooling = ProjectToolingService();
      final missing = await tooling.runPatrolSweep(
        tempDir.path,
        allowEmpty: true,
      );
      expect(missing.ok, isTrue);
      expect(missing.output, contains('does not exist yet'));

      Directory(p.join(tempDir.path, 'patrol_test')).createSync();
      final empty = await tooling.runPatrolSweep(
        tempDir.path,
        allowEmpty: true,
      );
      expect(empty.ok, isTrue);
      expect(empty.output, contains('empty suite'));

      final strict = await tooling.runPatrolSweep(tempDir.path);
      expect(strict.ok, isFalse);
      expect(strict.output, contains('No runnable Patrol tests'));
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });
}
