import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/models/models.dart';
import 'package:patroller/services/command_builder.dart';

void main() {
  group('buildPatrolCommand develop modes', () {
    late Directory projectDir;
    late String projectPath;
    late String targetFile;

    setUp(() {
      projectDir = Directory.systemTemp.createTempSync('patroller_cmd_');
      projectPath = projectDir.path;
      final testDir = Directory('$projectPath/patrol_test')..createSync();
      targetFile = '${testDir.path}/login_test.dart';
      File(targetFile).writeAsStringSync('void main() {}');
    });

    tearDown(() {
      if (projectDir.existsSync()) {
        projectDir.deleteSync(recursive: true);
      }
    });

    test('develop includes --target', () {
      final command = buildPatrolCommand(
        PatrolCommandInput(
          patrolExecutable: 'patrol',
          config: RunConfig(
            projectPath: projectPath,
            runMode: RunMode.develop,
            targetFile: targetFile,
            deviceId: 'sim-1',
          ),
        ),
      );

      expect(command.args, contains('develop'));
      expect(command.args, contains('--target'));
      expect(command.args, contains('patrol_test/login_test.dart'));
      expect(command.args, contains('-d'));
      expect(command.args, contains('sim-1'));
    });

    test('develop suite always includes --target', () {
      final command = buildPatrolCommand(
        PatrolCommandInput(
          patrolExecutable: 'patrol',
          config: RunConfig(
            projectPath: projectPath,
            runMode: RunMode.developSuite,
            targetFile: targetFile,
          ),
        ),
      );

      expect(
        command.args,
        containsAllInOrder(
            ['develop', '--target', 'patrol_test/login_test.dart']),
      );
    });

    test('develop throws when target is missing', () {
      expect(
        () => buildPatrolCommand(
          PatrolCommandInput(
            patrolExecutable: 'patrol',
            config: RunConfig(
              projectPath: projectPath,
              runMode: RunMode.developSuite,
            ),
          ),
        ),
        throwsArgumentError,
      );
    });

    test('test mode forces PATROL_HOT_RESTART=false', () {
      final command = buildPatrolCommand(
        PatrolCommandInput(
          patrolExecutable: 'patrol',
          config: RunConfig(
            projectPath: projectPath,
            runMode: RunMode.test,
            targetFile: targetFile,
            deviceId: 'sim-1',
          ),
        ),
      );

      expect(command.args, contains('test'));
      expect(command.args, contains('--dart-define'));
      expect(command.args, contains('PATROL_HOT_RESTART=false'));
      expect(command.args, isNot(contains('develop')));
    });

    test('full suite forces PATROL_HOT_RESTART=false', () {
      final command = buildPatrolCommand(
        PatrolCommandInput(
          patrolExecutable: 'patrol',
          config: RunConfig(
            projectPath: projectPath,
            runMode: RunMode.fullSuite,
          ),
        ),
      );

      expect(command.args.first, 'test');
      expect(command.args, contains('PATROL_HOT_RESTART=false'));
    });

    test('develop does not force PATROL_HOT_RESTART=false', () {
      final command = buildPatrolCommand(
        PatrolCommandInput(
          patrolExecutable: 'patrol',
          config: RunConfig(
            projectPath: projectPath,
            runMode: RunMode.develop,
            targetFile: targetFile,
          ),
        ),
      );

      expect(command.args, isNot(contains('PATROL_HOT_RESTART=false')));
    });

    test('develop forwards live profile and staging runtime controls', () {
      final command = buildPatrolCommand(
        PatrolCommandInput(
          patrolExecutable: 'patrol',
          config: RunConfig(
            projectPath: projectPath,
            runMode: RunMode.develop,
            targetFile: targetFile,
            deviceId: 'sim-1',
            env: TargetEnvironment.stg,
            userMode: UserMode.live,
            username: 'live@example.com',
            password: 'secret',
          ),
        ),
      );

      expect(command.args, containsAllInOrder(['--flavor', 'myastro_stg']));
      expect(command.args, contains('--no-uninstall'));
      expect(command.args, contains('--dart-define=PATROL_DATA_MODE=live'));
      expect(
        command.args,
        contains('--dart-define=PATROL_LIVE_EMAIL=live@example.com'),
      );
      expect(
        command.args,
        contains('--dart-define=PATROL_LIVE_PASSWORD=secret'),
      );
      expect(
        command.args,
        contains('--dart-define=PATROL_SKIP_NATIVE_PERMISSION_IPC=1'),
      );
    });
  });
}
