import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/domain/agent_prompts.dart';

void main() {
  group('agent prompts', () {
    test('catalog includes patrol coverage exploration', () {
      expect(agentPromptCatalog, isNotEmpty);
      expect(
        agentPromptCatalog.any(
          (m) => m.id == AgentPromptId.patrolCoverageExploration,
        ),
        isTrue,
      );
    });

    test('context builds portable launch command without absolute flutter path',
        () {
      const ctx = AgentPromptContext(
        projectName: 'myastro-flutter',
        projectPath: '/Users/dev/myastro-flutter',
        flutterExecutable: '/Users/dev/flutter/bin/flutter',
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
        'flutter run -t lib/main_stg.dart --flavor=myastro_stg',
      );
      expect(ctx.portableFlutterCommand, 'flutter');
      expect(ctx.packageEntryImport, 'package:myastro-flutter/main_stg.dart');
      expect(ctx.appLabel, 'myastro_stg');
      expect(
        ctx.deviceHintLine,
        contains('currently selected simulator in Patroller'),
      );
      expect(ctx.deviceHintLine, contains('iPhone 17 Pro Max'));
    });

    test('fvm path resolves to portable fvm flutter command', () {
      const ctx = AgentPromptContext(
        projectName: 'demo',
        projectPath: '/tmp/demo',
        flutterExecutable: '/Users/dev/fvm/default/bin/flutter',
        deviceName: '',
        entryTarget: 'lib/main.dart',
        flavorArgs: '',
        patrolTestDir: 'patrol_test',
        loginEmail: 'user@example.com',
        loginPassword: 'your_password',
      );

      expect(ctx.portableFlutterCommand, 'fvm flutter');
      expect(ctx.launchCommand, 'fvm flutter run -t lib/main.dart');
    });

    test('render patrol coverage prompt stays portable in core sections', () {
      const ctx = AgentPromptContext(
        projectName: 'myastro-flutter',
        projectPath: '/Users/dev/myastro-flutter',
        flutterExecutable: '/Users/dev/fvm/default/bin/flutter',
        deviceName: 'iPhone 17 Pro Max',
        entryTarget: 'lib/main_stg.dart',
        flavorArgs: '--flavor=myastro_stg',
        patrolTestDir: 'patrol_test',
        loginEmail: 'user@example.com',
        loginPassword: 'your_password',
        stagingAppLabel: 'myastro_stg',
      );

      final prompt = renderAgentPrompt(
        AgentPromptId.patrolCoverageExploration,
        ctx,
      );

      expect(prompt, contains('myastro-flutter'));
      expect(prompt, contains('lib/main_stg.dart'));
      expect(prompt, contains('--flavor=myastro_stg'));
      expect(prompt, contains('patrol_test/'));
      expect(prompt, contains('fvm flutter run -t lib/main_stg.dart'));
      expect(prompt, contains('currently selected simulator in Patroller'));
      expect(prompt, contains('iPhone 17 Pro Max'));
      expect(prompt, contains('package:myastro-flutter/main_stg.dart'));
      expect(prompt, contains('user@example.com'));
      expect(prompt, contains('your_password'));
      expect(prompt, contains('Patrol MCP'));
      expect(prompt, contains('Phase 0'));
      expect(prompt, contains('coverage map'));
      expect(prompt, contains('Local binding (optional)'));
      expect(prompt, isNot(contains('{{')));

      // Absolute host paths belong only in the optional Local binding section.
      final core = prompt.split('## Local binding (optional)').first;
      expect(core, isNot(contains('/Users/dev/myastro-flutter')));
      expect(core, isNot(contains('/Users/dev/fvm/default/bin/flutter')));
      expect(
        core,
        isNot(contains('-d "iPhone 17 Pro Max"')),
      );

      final binding = prompt.split('## Local binding (optional)').last;
      expect(binding, contains('/Users/dev/myastro-flutter'));
      expect(binding, contains('/Users/dev/fvm/default/bin/flutter'));
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

    test('missing device leaves name empty and soft-hints selected simulator',
        () {
      final ctx = buildAgentPromptContext(
        projectName: 'demo',
        projectPath: '/tmp/x',
        flutterExecutable: 'flutter',
        deviceName: null,
      );
      expect(ctx.deviceName, isEmpty);
      expect(
        ctx.deviceHintLine,
        'the currently selected simulator in Patroller',
      );
    });
  });
}
