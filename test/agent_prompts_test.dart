import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/domain/agent_prompts.dart';

void main() {
  group('agent prompts', () {
    test('catalog includes marionette coverage exploration', () {
      expect(agentPromptCatalog, isNotEmpty);
      expect(
        agentPromptCatalog.any(
          (m) => m.id == AgentPromptId.marionetteCoverageExploration,
        ),
        isTrue,
      );
    });

    test('context builds launch command with flutter, target, flavor, device',
        () {
      const ctx = AgentPromptContext(
        projectName: 'myastro-flutter',
        projectPath: '/Users/dev/myastro-flutter',
        flutterExecutable:
            '/Users/ahdaiman/develop/fvm/versions/3.44.1/bin/flutter',
        deviceName: 'iPhone 17 Pro Max',
        entryTarget: 'lib/main_stg.dart',
        flavorArgs: '--flavor=myastro_stg',
        patrolTestDir: 'patrol_test',
        loginEmail: 'user@example.com',
        loginPassword: 'your_password',
        stagingAppLabel: 'myastro_stg',
      );

      expect(
        ctx.launchCommand,
        '/Users/ahdaiman/develop/fvm/versions/3.44.1/bin/flutter run '
        '-t lib/main_stg.dart --flavor=myastro_stg '
        '-d "iPhone 17 Pro Max" 2>&1',
      );
      expect(ctx.appLabel, 'myastro_stg');
    });

    test('render marionette coverage prompt substitutes project + launch', () {
      const ctx = AgentPromptContext(
        projectName: 'myastro-flutter',
        projectPath: '/Users/dev/myastro-flutter',
        flutterExecutable:
            '/Users/ahdaiman/develop/fvm/versions/3.44.1/bin/flutter',
        deviceName: 'iPhone 17 Pro Max',
        entryTarget: 'lib/main_stg.dart',
        flavorArgs: '--flavor=myastro_stg',
        patrolTestDir: 'patrol_test',
        loginEmail: 'user@example.com',
        loginPassword: 'your_password',
        stagingAppLabel: 'myastro_stg',
      );

      final prompt = renderAgentPrompt(
        AgentPromptId.marionetteCoverageExploration,
        ctx,
      );

      expect(prompt, contains('myastro-flutter'));
      expect(prompt, contains('/Users/dev/myastro-flutter'));
      expect(prompt, contains('myastro_stg'));
      expect(prompt, contains('lib/main_stg.dart'));
      expect(prompt, contains('--flavor=myastro_stg'));
      expect(prompt, contains('iPhone 17 Pro Max'));
      expect(prompt, contains('user@example.com'));
      expect(prompt, contains('your_password'));
      expect(prompt, contains('Marionette MCP'));
      expect(prompt, contains('Patrol MCP'));
      expect(prompt, contains('Never create duplicate coverage'));
      expect(prompt, contains('Final Report'));
      expect(prompt, isNot(contains('{{')));
    });

    test('myastro project name defaults flavor and label', () {
      final ctx = buildAgentPromptContext(
        projectName: 'myastro-flutter',
        projectPath: '/tmp/does-not-need-to-exist-for-name-heuristics',
        flutterExecutable: 'flutter',
        deviceName: 'iPhone 17 Pro Max',
      );
      expect(ctx.flavorArgs, '--flavor=myastro_stg');
      expect(ctx.appLabel, 'myastro_stg');
      expect(ctx.deviceName, 'iPhone 17 Pro Max');
    });

    test('missing device falls back to iPhone 17 Pro Max', () {
      final ctx = buildAgentPromptContext(
        projectName: 'demo',
        projectPath: '/tmp/x',
        flutterExecutable: 'flutter',
        deviceName: null,
      );
      expect(ctx.deviceName, 'iPhone 17 Pro Max');
    });
  });
}
