import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/services/opencode_service.dart';

void main() {
  test('writeIsolatedConfig writes valid json config with mcp servers and model', () async {
    final tempDir = Directory.systemTemp.createTempSync('opencode_test_config_');
    try {
      final configPath = await OpenCodeService().writeIsolatedConfig(
        directory: tempDir.path,
        projectPath: '/test/project',
        patrolCommand: 'dart',
        patrolArgs: ['run', 'patrol_mcp'],
        patrolEnvironment: {'PROJECT_ROOT': '/test/project'},
        marionetteCommand: 'marionette_mcp',
        marionetteArgs: [],
        model: 'provider/free-model',
      );

      final configFile = File(configPath);
      expect(configFile.existsSync(), isTrue);

      final content = configFile.readAsStringSync();
      expect(content, contains('"model": "provider/free-model"'));
      expect(content, contains('"patrol"'));
      expect(content, contains('"marionette"'));
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('OpenCodeStatus holds correct properties', () {
    const status = OpenCodeStatus(
      available: true,
      executable: '/usr/local/bin/opencode',
      version: '1.2.3',
    );
    expect(status.available, isTrue);
    expect(status.version, '1.2.3');
    expect(status.executable, '/usr/local/bin/opencode');
  });

  test('parseVerifiedFreeModels keeps only opencode/*-free with zero costs', () {
    const verbose = '''
opencode/deepseek-v4-flash-free
{"cost":{"input":0,"output":0}}
opencode/laguna-s-2.1-free
{"cost":{"input":0,"output":0}}
botlab/claude-opus-5
{"cost":{"input":0,"output":0}}
botlab/gpt-5.6-sol
{"cost":{"input":0,"output":0}}
botlab/kimi-k3
{"cost":{"input":0,"output":0}}
xai/grok-imagine-image
{"cost":{"input":0,"output":0}}
xai/grok-imagine-video
{"cost":{"input":0,"output":0}}
opencode/paid-tier-model
{"cost":{"input":0.001,"output":0.002}}
opencode/zero-cost-but-not-free-suffix
{"cost":{"input":0,"output":0}}
anthropic/claude-sonnet-4
{"cost":{"input":3,"output":15}}
''';

    final models = OpenCodeService().parseVerifiedFreeModels(verbose);

    expect(
      models.map((m) => m.id).toList(),
      [
        'opencode/deepseek-v4-flash-free',
        'opencode/laguna-s-2.1-free',
      ],
    );
    expect(models.every((m) => m.provider == 'opencode'), isTrue);
    expect(models.every((m) => m.id.endsWith('-free')), isTrue);
    expect(models.every((m) => m.verifiedFree), isTrue);
  });

  test('parseAllModels parses all valid model entries including non-free/subscription models', () {
    const verbose = '''
opencode/deepseek-v4-flash-free
{"cost":{"input":0,"output":0}}
opencode/claude-3-5-sonnet
{"cost":{"input":0.003,"output":0.015}}
anthropic/claude-3-5-haiku
{"cost":{"input":0.001,"output":0.005}}
''';

    final models = OpenCodeService().parseAllModels(verbose);

    expect(models.length, 3);
    expect(models.map((m) => m.id).toList(), [
      'opencode/deepseek-v4-flash-free',
      'opencode/claude-3-5-sonnet',
      'anthropic/claude-3-5-haiku',
    ]);
    expect(models[0].verifiedFree, isTrue);
    expect(models[1].verifiedFree, isFalse);
  });

  test('parseVerifiedFreeModels rejects missing or non-zero costs', () {
    const verbose = '''
opencode/missing-cost-free
{"name":"missing-cost-free"}
opencode/partial-cost-free
{"cost":{"input":0}}
opencode/nonzero-input-free
{"cost":{"input":0.1,"output":0}}
opencode/nonzero-output-free
{"cost":{"input":0,"output":0.1}}
opencode/valid-free
{"cost":{"input":0,"output":0}}
''';

    final models = OpenCodeService().parseVerifiedFreeModels(verbose);

    expect(models.map((m) => m.id).toList(), ['opencode/valid-free']);
  });

  test('splitModelRef parses provider/model ids for OpenCode HTTP API', () {
    expect(
      OpenCodeService.splitModelRef('opencode/mimo-v2.5-free'),
      (providerID: 'opencode', modelID: 'mimo-v2.5-free'),
    );
    expect(
      OpenCodeService.splitModelRef('solo-model'),
      (providerID: 'opencode', modelID: 'solo-model'),
    );
  });

  test('isSessionIdleAfterWork requires busy then idle for same session', () {
    const sessionId = 'ses_abc';
    final busy = {
      'type': 'session.status',
      'properties': {
        'sessionID': sessionId,
        'status': {'type': 'busy'},
      },
    };
    final idle = {
      'type': 'session.status',
      'properties': {
        'sessionID': sessionId,
        'status': {'type': 'idle'},
      },
    };

    expect(
      OpenCodeService.isSessionBusyEvent(event: busy, sessionId: sessionId),
      isTrue,
    );
    expect(
      OpenCodeService.isSessionIdleAfterWork(
        event: idle,
        sessionId: sessionId,
        sawBusy: false,
      ),
      isFalse,
    );
    expect(
      OpenCodeService.isSessionIdleAfterWork(
        event: idle,
        sessionId: sessionId,
        sawBusy: true,
      ),
      isTrue,
    );
    expect(
      OpenCodeService.isSessionIdleAfterWork(
        event: idle,
        sessionId: 'ses_other',
        sawBusy: true,
      ),
      isFalse,
    );
  });
}
