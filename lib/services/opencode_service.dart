import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'cli_env.dart';
import '../domain/routine_models.dart';

/// Detects and configures OpenCode (opencode.ai) for MCP integration.
///
/// OpenCode is a free, open-source AI coding agent that supports MCP servers.
/// Patroller writes MCP config to OpenCode so agents can run Patrol/Marionette
/// against the currently open project.
class OpenCodeService {
  Process? _routineProcess;

  Future<String?> getInstallCommand() async {
    if (!Platform.isMacOS) return null;
    final brew = resolveExecutable('brew');
    if (await _commandAvailable(brew, const ['--version'])) {
      return 'brew install anomalyco/tap/opencode';
    }
    final npm = resolveExecutable('npm');
    if (await _commandAvailable(npm, const ['--version'])) {
      return 'npm install -g opencode-ai@latest';
    }
    return null;
  }

  Future<bool> installOnMac() async {
    if (!Platform.isMacOS) return false;
    final brew = resolveExecutable('brew');
    if (await _commandAvailable(brew, const ['--version'])) {
      final result = await Process.run(brew, const [
        'install',
        'anomalyco/tap/opencode',
      ], environment: developerToolEnv());
      return result.exitCode == 0;
    }
    final npm = resolveExecutable('npm');
    if (await _commandAvailable(npm, const ['--version'])) {
      final result = await Process.run(npm, const [
        'install',
        '-g',
        'opencode-ai@latest',
      ], environment: developerToolEnv());
      return result.exitCode == 0;
    }
    return false;
  }

  Future<bool> _commandAvailable(String executable, List<String> args) async {
    try {
      final result = await Process.run(
        executable,
        args,
        environment: developerToolEnv(),
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Detects if opencode is available on this machine.
  Future<OpenCodeStatus> detect() async {
    final resolved = resolveExecutable('opencode');
    final version = await _getVersion(resolved);
    final found = version != null;

    final configDir = _configDir();
    final hasConfigDir = configDir != null && Directory(configDir).existsSync();
    final configPath = configDir != null
        ? p.join(configDir, 'opencode.jsonc')
        : null;
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

  Future<List<OpenCodeModel>> listVerifiedFreeModels() async {
    final resolved = resolveExecutable('opencode');
    try {
      final result = await Process.run(resolved, const [
        'models',
        '--refresh',
        '--verbose',
      ], environment: developerToolEnv());
      if (result.exitCode != 0) return const [];
      return parseVerifiedFreeModels('${result.stdout}');
    } catch (_) {
      return const [];
    }
  }

  /// Parses `opencode models --refresh --verbose` output into verified free
  /// OpenCode models only (`opencode/*-free` with explicit zero input/output cost).
  List<OpenCodeModel> parseVerifiedFreeModels(String output) {
    final result = <OpenCodeModel>[];
    String? current;
    var block = StringBuffer();
    void flush() {
      final id = current;
      if (id == null || block.length == 0) return;
      final input = _cost(block.toString(), 'input');
      final outputCost = _cost(block.toString(), 'output');
      if (_isVerifiedOpenCodeFreeModel(id, input, outputCost)) {
        final slash = id.indexOf('/');
        result.add(
          OpenCodeModel(
            id: id,
            provider: slash < 0 ? id : id.substring(0, slash),
            name: slash < 0 ? id : id.substring(slash + 1),
            inputCost: input,
            outputCost: outputCost,
          ),
        );
      }
      block = StringBuffer();
    }

    for (final line in output.split('\n')) {
      final trimmed = line.trim();
      if (RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.:-]+$').hasMatch(trimmed)) {
        flush();
        current = trimmed;
      } else if (current != null) {
        block.write(trimmed);
      }
    }
    flush();
    return result;
  }

  /// OpenCode free catalog entries use the `opencode/` provider and a `-free`
  /// id suffix; zero cost alone is not enough (other providers can report 0/0).
  bool _isVerifiedOpenCodeFreeModel(
    String id,
    double? inputCost,
    double? outputCost,
  ) {
    return id.startsWith('opencode/') &&
        id.endsWith('-free') &&
        inputCost == 0 &&
        outputCost == 0;
  }

  double? _cost(String text, String key) {
    final match = RegExp(
      '"$key"\\s*:\\s*(-?[0-9]+(?:\\.[0-9]+)?)',
    ).firstMatch(text);
    return match == null ? null : double.tryParse(match.group(1)!);
  }

  Future<String> writeIsolatedConfig({
    required String directory,
    required String projectPath,
    required String patrolCommand,
    required List<String> patrolArgs,
    required Map<String, String> patrolEnvironment,
    required String marionetteCommand,
    required List<String> marionetteArgs,
    Map<String, String> marionetteEnvironment = const {},
    required String model,
  }) async {
    final dir = Directory(directory);
    if (!dir.existsSync()) await dir.create(recursive: true);
    final path = p.join(directory, 'opencode-routine.json');
    final config = <String, dynamic>{
      r'$schema': 'https://opencode.ai/config.json',
      'model': model,
      'permission': {'*': 'allow', 'external_directory': 'deny'},
      'mcp': {
        'patrol': {
          'type': 'local',
          'command': [patrolCommand, ...patrolArgs],
          'environment': patrolEnvironment,
          'enabled': true,
        },
        'marionette': {
          'type': 'local',
          'command': [marionetteCommand, ...marionetteArgs],
          'environment': marionetteEnvironment,
          'enabled': true,
        },
      },
    };
    await File(path).writeAsString(JsonEncoder.withIndent('  ').convert(config));
    return path;
  }

  Process? _serverProcess;
  int? _serverPort;
  String? _activeSessionId;

  Future<int> startServer({
    required String configPath,
    int port = 4096,
  }) async {
    final executable = resolveExecutable('opencode');
    _serverPort = port;
    _serverProcess = await Process.start(
      executable,
      ['serve', '--port', '$port'],
      environment: {...developerToolEnv(), 'OPENCODE_CONFIG': configPath},
      runInShell: false,
    );
    // Give server process time to bind
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return port;
  }

  Future<int> runRoutine({
    required String projectPath,
    required String model,
    required String prompt,
    required String configPath,
    void Function(String line)? onOutput,
    void Function(PermissionRequest request)? onPermissionRequest,
  }) async {
    final executable = resolveExecutable('opencode');

    void handleLine(String line) {
      onOutput?.call(line);
      try {
        if (line.trim().startsWith('{') && line.trim().endsWith('}')) {
          final data = jsonDecode(line);
          if (data is Map<String, dynamic> &&
              data['type'] == 'permission_request') {
            final request = PermissionRequest(
              id: data['id'] as String? ?? 'req_${DateTime.now().millisecondsSinceEpoch}',
              tool: data['tool'] as String? ?? 'unknown_tool',
              description: data['description'] as String? ?? 'Out-of-scope operation requested',
              params: (data['params'] as Map?)?.cast<String, dynamic>() ?? {},
            );
            onPermissionRequest?.call(request);
          }
        }
      } catch (_) {}
    }

    // 1. Primary: Dedicated OpenCode HTTP Server & Event Stream API
    try {
      final port = await startServer(configPath: configPath);
      onOutput?.call('[OpenCode Server API] Dedicated server listening on http://127.0.0.1:$port');

      final client = HttpClient();
      final req = await client.postUrl(Uri.parse('http://127.0.0.1:$port/session'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'model': model,
        'prompt': prompt,
        'directory': projectPath,
      }));
      final resp = await req.close();
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        onOutput?.call('[OpenCode Server API] Session initialized over HTTP: ${resp.statusCode}');
        
        final eventsReq = await client.getUrl(Uri.parse('http://127.0.0.1:$port/events'));
        final eventsResp = await eventsReq.close();
        final completer = Completer<int>();
        
        eventsResp
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) => handleLine(line), onDone: () {
          if (!completer.isCompleted) completer.complete(0);
        }, onError: (_) {
          if (!completer.isCompleted) completer.complete(1);
        });

        final code = await completer.future;
        await stopServer();
        return code;
      }
    } catch (e) {
      onOutput?.call('[OpenCode Server API] HTTP server session mode fallback: $e');
    }

    // 2. Fallback: Isolated OpenCode CLI runner process
    _routineProcess = await Process.start(
      executable,
      ['run', '--format', 'json', '--model', model, prompt],
      workingDirectory: projectPath,
      environment: {...developerToolEnv(), 'OPENCODE_CONFIG': configPath},
      runInShell: false,
    );
    final process = _routineProcess!;

    final subscriptions = <StreamSubscription<dynamic>>[
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(handleLine),
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(onOutput ?? (_) {}),
    ];
    final code = await process.exitCode;
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    _routineProcess = null;
    await stopServer();
    return code;
  }

  void respondPermission({required String id, required bool allow}) {
    // 1. Try HTTP Server API permission endpoint
    if (_serverPort != null) {
      final client = HttpClient();
      final uri = Uri.parse('http://127.0.0.1:$_serverPort/permission/respond');
      client.postUrl(uri).then((req) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({
          'id': id,
          'decision': allow ? 'allow' : 'deny',
        }));
        return req.close();
      }).then((resp) {
        client.close();
      }).catchError((_) {
        client.close();
      });
    }

    // 2. Also send via stdin for CLI runner process
    if (_routineProcess != null) {
      final response = jsonEncode({
        'type': 'permission_response',
        'id': id,
        'decision': allow ? 'allow' : 'deny',
      });
      _routineProcess!.stdin.writeln(response);
    }
  }

  Future<void> stopServer() async {
    _serverProcess?.kill(ProcessSignal.sigterm);
    _serverProcess = null;
    _serverPort = null;
  }

  Future<void> stopRoutine() async {
    _routineProcess?.kill(ProcessSignal.sigterm);
    _routineProcess = null;
    await stopServer();
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
      final result = await Process.run(executable, [
        '--version',
      ], environment: developerToolEnv());
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

    final payload = <String, dynamic>{...existing, 'mcpServers': servers};

    // OpenCode uses JSONC (JSON with comments), but we write valid JSON.
    await File(
      configPath,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(payload));

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
