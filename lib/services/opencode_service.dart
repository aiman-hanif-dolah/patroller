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

  Future<List<OpenCodeModel>> listModels({bool freeOnly = true}) async {
    final resolved = resolveExecutable('opencode');
    try {
      final result = await Process.run(resolved, const [
        'models',
        '--refresh',
        '--verbose',
      ], environment: developerToolEnv());
      if (result.exitCode != 0) return const [];
      final raw = '${result.stdout}';
      return freeOnly ? parseVerifiedFreeModels(raw) : parseAllModels(raw);
    } catch (_) {
      return const [];
    }
  }

  Future<List<OpenCodeModel>> listVerifiedFreeModels() =>
      listModels(freeOnly: true);

  /// Parses `opencode models --refresh --verbose` output into all available
  /// models parsed from OpenCode output.
  List<OpenCodeModel> parseAllModels(String output) {
    final result = <OpenCodeModel>[];
    String? current;
    var block = StringBuffer();
    void flush() {
      final id = current;
      if (id == null || block.length == 0) return;
      final input = _cost(block.toString(), 'input');
      final outputCost = _cost(block.toString(), 'output');
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

  /// Parses `opencode models --refresh --verbose` output into verified free
  /// OpenCode models only (`opencode/*-free` with explicit zero input/output cost).
  List<OpenCodeModel> parseVerifiedFreeModels(String output) {
    return parseAllModels(output)
        .where(
          (model) => _isVerifiedOpenCodeFreeModel(
            model.id,
            model.inputCost,
            model.outputCost,
          ),
        )
        .toList();
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
  String? _activeDirectory;
  Completer<int>? _routineCompleter;
  HttpClient? _httpClient;
  StreamSubscription<dynamic>? _eventSubscription;

  /// Splits `provider/model` into OpenCode API fields.
  static ({String providerID, String modelID}) splitModelRef(String model) {
    final slash = model.indexOf('/');
    if (slash <= 0 || slash >= model.length - 1) {
      return (providerID: 'opencode', modelID: model);
    }
    return (
      providerID: model.substring(0, slash),
      modelID: model.substring(slash + 1),
    );
  }

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

  Uri _serverUri(String path, {Map<String, String>? query}) {
    return Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: _serverPort,
      path: path,
      queryParameters: {
        if (_activeDirectory != null && _activeDirectory!.isNotEmpty)
          'directory': _activeDirectory!,
        ...?query,
      },
    );
  }

  Future<String> _readBody(HttpClientResponse response) async {
    return (await response.transform(utf8.decoder).join()).trim();
  }

  void _handlePermissionEvent(
    Map<String, dynamic> event,
    void Function(PermissionRequest request)? onPermissionRequest,
  ) {
    if (onPermissionRequest == null) return;
    final type = event['type'] as String?;
    if (type != 'permission.asked' && type != 'permission.v2.asked') return;
    final props = event['properties'];
    if (props is! Map) return;
    final map = props.cast<String, dynamic>();
    final id = map['id'] as String?;
    if (id == null || id.isEmpty) return;
    final permission = (map['permission'] ?? map['action'] ?? 'permission')
        .toString();
    final patterns = map['patterns'] ?? map['resources'] ?? const [];
    onPermissionRequest(
      PermissionRequest(
        id: id,
        tool: permission,
        description: '$permission $patterns',
        params: map,
      ),
    );
  }

  /// True when an SSE payload indicates the prompted session became idle again.
  static bool isSessionIdleAfterWork({
    required Map<String, dynamic> event,
    required String sessionId,
    required bool sawBusy,
  }) {
    if (!sawBusy) return false;
    if (event['type'] != 'session.status') return false;
    final props = event['properties'];
    if (props is! Map) return false;
    if (props['sessionID'] != sessionId) return false;
    final status = props['status'];
    if (status is! Map) return false;
    return status['type'] == 'idle';
  }

  static bool isSessionBusyEvent({
    required Map<String, dynamic> event,
    required String sessionId,
  }) {
    if (event['type'] != 'session.status') return false;
    final props = event['properties'];
    if (props is! Map) return false;
    if (props['sessionID'] != sessionId) return false;
    final status = props['status'];
    if (status is! Map) return false;
    return status['type'] == 'busy';
  }

  Future<int?> _runViaHttpServer({
    required String projectPath,
    required String model,
    required String prompt,
    required String configPath,
    void Function(String line)? onOutput,
    void Function(PermissionRequest request)? onPermissionRequest,
  }) async {
    final port = await startServer(configPath: configPath);
    _activeDirectory = projectPath;
    onOutput?.call(
      '[OpenCode Server API] Dedicated server listening on http://127.0.0.1:$port',
    );

    final client = HttpClient();
    _httpClient = client;
    final modelRef = splitModelRef(model);

    final createReq = await client.postUrl(_serverUri('/session'));
    createReq.headers.contentType = ContentType.json;
    createReq.write(
      jsonEncode({
        'title': 'Patroller routine',
        'model': {
          'providerID': modelRef.providerID,
          'id': modelRef.modelID,
        },
      }),
    );
    final createResp = await createReq.close();
    final createBody = await _readBody(createResp);
    if (createResp.statusCode != 200 && createResp.statusCode != 201) {
      onOutput?.call(
        '[OpenCode Server API] Session create failed (${createResp.statusCode}): $createBody',
      );
      client.close(force: true);
      _httpClient = null;
      return null;
    }

    final created = jsonDecode(createBody);
    if (created is! Map || created['id'] is! String) {
      onOutput?.call(
        '[OpenCode Server API] Session create returned unexpected body: $createBody',
      );
      client.close(force: true);
      _httpClient = null;
      return null;
    }
    final sessionId = created['id'] as String;
    _activeSessionId = sessionId;
    onOutput?.call(
      '[OpenCode Server API] Session initialized over HTTP: $sessionId',
    );

    final completer = Completer<int>();
    _routineCompleter = completer;
    var sawBusy = false;

    final eventsReq = await client.getUrl(_serverUri('/event'));
    eventsReq.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    final eventsResp = await eventsReq.close();
    _eventSubscription = eventsResp
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) return;
        onOutput?.call(trimmed);

        var payload = trimmed;
        if (payload.startsWith('data:')) {
          payload = payload.substring(5).trim();
        }
        if (!payload.startsWith('{')) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is! Map<String, dynamic>) return;
          _handlePermissionEvent(decoded, onPermissionRequest);
          if (isSessionBusyEvent(event: decoded, sessionId: sessionId)) {
            sawBusy = true;
          }
          if (isSessionIdleAfterWork(
            event: decoded,
            sessionId: sessionId,
            sawBusy: sawBusy,
          )) {
            if (!completer.isCompleted) completer.complete(0);
          }
        } catch (_) {}
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete(sawBusy ? 0 : 1);
      },
      onError: (Object error) {
        onOutput?.call('[OpenCode Server API] Event stream error: $error');
        if (!completer.isCompleted) completer.complete(1);
      },
    );

    final promptReq = await client.postUrl(
      _serverUri('/session/$sessionId/prompt_async'),
    );
    promptReq.headers.contentType = ContentType.json;
    promptReq.write(
      jsonEncode({
        'model': {
          'providerID': modelRef.providerID,
          'modelID': modelRef.modelID,
        },
        'parts': [
          {'type': 'text', 'text': prompt},
        ],
      }),
    );
    final promptResp = await promptReq.close();
    final promptBody = await _readBody(promptResp);
    if (promptResp.statusCode != 204 &&
        promptResp.statusCode != 200 &&
        promptResp.statusCode != 201) {
      onOutput?.call(
        '[OpenCode Server API] Prompt failed (${promptResp.statusCode}): $promptBody',
      );
      if (!completer.isCompleted) completer.complete(1);
    } else {
      onOutput?.call('[OpenCode Server API] Prompt accepted for session $sessionId');
    }

    final code = await completer.future;
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    client.close(force: true);
    _httpClient = null;
    _routineCompleter = null;
    _activeSessionId = null;
    return code;
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
        var trimmed = line.trim();
        if (trimmed.startsWith('data:')) {
          trimmed = trimmed.substring(5).trim();
        }
        if (!(trimmed.startsWith('{') && trimmed.endsWith('}'))) return;
        final data = jsonDecode(trimmed);
        if (data is! Map<String, dynamic>) return;
        if (data['type'] == 'permission_request') {
          onPermissionRequest?.call(
            PermissionRequest(
              id: data['id'] as String? ??
                  'req_${DateTime.now().millisecondsSinceEpoch}',
              tool: data['tool'] as String? ?? 'unknown_tool',
              description: data['description'] as String? ??
                  'Out-of-scope operation requested',
              params: (data['params'] as Map?)?.cast<String, dynamic>() ?? {},
            ),
          );
          return;
        }
        _handlePermissionEvent(data, onPermissionRequest);
      } catch (_) {}
    }

    // 1. Primary: Dedicated OpenCode HTTP Server & Event Stream API
    try {
      final httpCode = await _runViaHttpServer(
        projectPath: projectPath,
        model: model,
        prompt: prompt,
        configPath: configPath,
        onOutput: onOutput,
        onPermissionRequest: onPermissionRequest,
      );
      if (httpCode != null) {
        await stopServer();
        return httpCode;
      }
      onOutput?.call(
        '[OpenCode Server API] HTTP session mode unavailable; falling back to CLI',
      );
      await stopServer();
    } catch (e) {
      onOutput?.call('[OpenCode Server API] HTTP server session mode fallback: $e');
      await stopServer();
    }

    // 2. Fallback: Isolated OpenCode CLI runner process
    _routineProcess = await Process.start(
      executable,
      [
        'run',
        '--format',
        'json',
        '--model',
        model,
        '--auto',
        prompt,
      ],
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
    final reply = allow ? 'once' : 'reject';
    // 1. OpenCode HTTP permission reply API
    if (_serverPort != null) {
      final client = HttpClient();
      final uri = _serverUri('/permission/$id/reply');
      client.postUrl(uri).then((req) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({'reply': reply}));
        return req.close();
      }).then((resp) async {
        await _readBody(resp);
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
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    _httpClient?.close(force: true);
    _httpClient = null;
    final pending = _routineCompleter;
    if (pending != null && !pending.isCompleted) {
      pending.complete(1);
    }
    _routineCompleter = null;
    _serverProcess?.kill(ProcessSignal.sigterm);
    _serverProcess = null;
    _serverPort = null;
    _activeSessionId = null;
    _activeDirectory = null;
  }

  Future<void> stopRoutine() async {
    if (_serverPort != null && _activeSessionId != null) {
      try {
        final client = HttpClient();
        final req = await client.postUrl(
          _serverUri('/session/$_activeSessionId/abort'),
        );
        final resp = await req.close();
        await _readBody(resp);
        client.close(force: true);
      } catch (_) {}
    }
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
