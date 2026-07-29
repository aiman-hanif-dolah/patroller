import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'cli_env.dart';

/// Detects and configures OpenCode (opencode.ai) for MCP integration.
///
/// OpenCode is a free, open-source AI coding agent that supports MCP servers.
/// Patroller writes MCP config to OpenCode so agents can run Patrol/Marionette
/// against the currently open project.
class OpenCodeService {
  /// Detects if opencode is available on this machine.
  Future<OpenCodeStatus> detect() async {
    final resolved = resolveExecutable('opencode');
    final found = File(resolved).existsSync() || resolved == 'opencode';

    String? version;
    if (found) {
      version = await _getVersion(resolved);
    }

    final configDir = _configDir();
    final hasConfigDir = configDir != null && Directory(configDir).existsSync();
    final configPath = configDir != null ? p.join(configDir, 'opencode.jsonc') : null;
    final hasConfig = configPath != null && File(configPath).existsSync();

    return OpenCodeStatus(
      available: found,
      executable: found ? resolved : null,
      version: version,
      configDir: configDir,
      configPath: configPath,
      hasConfigDir: hasConfigDir,
      hasConfig: hasConfig,
    );
  }

  /// Returns the opencode config directory path.
  String? _configDir() {
    final home = userHomeDirectory();
    if (home == null) return null;
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        return p.join(appData, 'opencode');
      }
    }
    return p.join(home, '.config', 'opencode');
  }

  Future<String?> _getVersion(String executable) async {
    try {
      final result = await Process.run(
        executable,
        ['--version'],
        environment: developerToolEnv(),
      );
      if (result.exitCode == 0) {
        final out = '${result.stdout}${result.stderr}'.trim();
        return out.isEmpty ? null : out;
      }
    } catch (_) {}
    return null;
  }

  /// Writes MCP server configuration to opencode's config file.
  ///
  /// Merges patrol + marionette servers into the existing config or creates
  /// a new one. Returns the config file path.
  Future<String> writeMcpConfig({
    required String projectPath,
    required String patrolCommand,
    required List<String> patrolArgs,
    required Map<String, String> patrolEnv,
    required String marionetteCommand,
    required List<String> marionetteArgs,
  }) async {
    final configDir = _configDir();
    if (configDir == null) {
      throw StateError('Cannot resolve opencode config directory');
    }

    final dir = Directory(configDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final configPath = p.join(configDir, 'opencode.jsonc');
    final existing = await _readConfig(configPath);

    final servers = Map<String, dynamic>.from(
      (existing['mcpServers'] as Map?)?.cast<String, dynamic>() ?? {},
    );

    servers['patrol'] = {
      'command': patrolCommand,
      'args': patrolArgs,
      'env': patrolEnv,
    };
    servers['marionette'] = {
      'command': marionetteCommand,
      'args': marionetteArgs,
    };

    final payload = <String, dynamic>{
      ...existing,
      'mcpServers': servers,
    };

    // OpenCode uses JSONC (JSON with comments), but we write valid JSON.
    await File(configPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );

    return configPath;
  }

  Future<Map<String, dynamic>> _readConfig(String path) async {
    final file = File(path);
    if (!file.existsSync()) return {};
    try {
      // Strip comments for JSONC files.
      var text = await file.readAsString();
      text = text.replaceAll(RegExp(r'//.*$', multiLine: true), '');
      text = text.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    return {};
  }
}

/// Status of OpenCode detection.
class OpenCodeStatus {
  const OpenCodeStatus({
    required this.available,
    this.executable,
    this.version,
    this.configDir,
    this.configPath,
    this.hasConfigDir = false,
    this.hasConfig = false,
  });

  final bool available;
  final String? executable;
  final String? version;
  final String? configDir;
  final String? configPath;
  final bool hasConfigDir;
  final bool hasConfig;
}
