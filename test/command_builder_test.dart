import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/models/models.dart';
import 'package:patroller/services/command_builder.dart';

void main() {
  group('buildPatrolCommand develop modes', () {
    const projectPath = '/tmp/myastro';
    const targetFile = '/tmp/myastro/patrol_test/login_test.dart';

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

      expect(command.args, ['develop', '--target', 'patrol_test/login_test.dart']);
    });

    test('develop throws when target is missing', () {
      expect(
        () => buildPatrolCommand(
          PatrolCommandInput(
            patrolExecutable: 'patrol',
            config: const RunConfig(
              projectPath: projectPath,
              runMode: RunMode.developSuite,
            ),
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}