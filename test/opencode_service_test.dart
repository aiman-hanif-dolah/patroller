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
}
