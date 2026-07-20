import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/agent_prompts.dart';
import 'cli_env.dart';

class McpRequirement {
  const McpRequirement({
    required this.id,
    required this.label,
    required this.ok,
    required this.detail,
    this.fixHint,
  });

  final String id;
  final String label;
  final bool ok;
  final String detail;
  final String? fixHint;
}

class McpToolStatus {
  const McpToolStatus({
    required this.name,
    required this.available,
    required this.command,
    this.version,
    this.error,
  });

  final String name;
  final bool available;
  final String command;
  final String? version;
  final String? error;
}

class McpRoutineResult {
  const McpRoutineResult({
    required this.ok,
    required this.message,
    this.wrapperPath,
    this.mcpConfigPath,
    this.patrolProbe,
    this.marionetteProbe,
  });

  final bool ok;
  final String message;
  final String? wrapperPath;
  final String? mcpConfigPath;
  final McpServerProbe? patrolProbe;
  final McpServerProbe? marionetteProbe;
}

/// Result of launching an MCP server and completing the initialize handshake.
class McpServerProbe {
  const McpServerProbe({
    required this.id,
    required this.label,
    required this.ok,
    required this.detail,
    this.serverName,
    this.serverVersion,
  });

  final String id;
  final String label;
  final bool ok;
  final String detail;
  final String? serverName;
  final String? serverVersion;
}

/// Result of installing (or updating) a global MCP package on this machine.
class McpInstallResult {
  const McpInstallResult({
    required this.package,
    required this.ok,
    required this.message,
    this.version,
  });

  final String package;
  final bool ok;
  final String message;
  final String? version;
}

/// Result of preparing an agent prompt routine (MCP bind + prompt file).
class AgentPromptRoutineResult {
  const AgentPromptRoutineResult({
    required this.ok,
    required this.message,
    this.promptPath,
    this.promptText,
    this.mcpConfigPath,
    this.wrapperPath,
  });

  final bool ok;
  final String message;
  final String? promptPath;
  final String? promptText;
  final String? mcpConfigPath;
  final String? wrapperPath;
}

/// Detects / installs / configures / probes Patrol MCP + Marionette MCP.
///
/// Packages are always installed **globally on this machine** via
/// `dart pub global activate` (never into the opened Flutter project).
/// Project path is only used when writing MCP config / wrappers so Cursor
/// agents can run Patrol against the currently open project.
class McpService {
  static const patrolPackage = 'patrol_mcp';
  static const marionettePackage = 'marionette_mcp';

  Future<List<McpRequirement>> checkRequirements({
    required String? projectPath,
  }) async {
    final reqs = <McpRequirement>[];

    final dart = await _probeTool('dart', ['--version']);
    reqs.add(
      McpRequirement(
        id: 'dart',
        label: 'Dart CLI',
        ok: dart.available,
        detail: dart.available
            ? (dart.version ?? 'Dart available')
            : 'Dart not found on PATH',
        fixHint: 'Install Flutter/Dart and ensure dart is on PATH',
      ),
    );

    final patrolMcp = await resolvePatrolMcp();
    reqs.add(
      McpRequirement(
        id: 'patrol_mcp',
        label: 'Patrol MCP (machine)',
        ok: patrolMcp.available,
        detail: patrolMcp.available
            ? (patrolMcp.version ?? 'patrol_mcp available (global)')
            : 'Not installed on this machine',
        fixHint:
            'Use Patroller → Agent → Install Patrol MCP '
            '(or: dart pub global activate patrol_mcp)',
      ),
    );

    final marionette = await resolveMarionetteMcp();
    reqs.add(
      McpRequirement(
        id: 'marionette_mcp',
        label: 'Marionette MCP (machine)',
        ok: marionette.available,
        detail: marionette.available
            ? (marionette.version ?? 'marionette_mcp available (global)')
            : 'Not installed on this machine',
        fixHint:
            'Use Patroller → Agent → Install Marionette MCP '
            '(or: dart pub global activate marionette_mcp)',
      ),
    );

    final project = projectPath;
    final hasProject =
        project != null && Directory(project).existsSync();
    reqs.add(
      McpRequirement(
        id: 'project',
        label: 'Flutter project',
        ok: hasProject,
        detail: hasProject ? project : 'No project open',
        fixHint: 'Open a Flutter project in Patroller',
      ),
    );

    if (project != null && Directory(project).existsSync()) {
      final pubspec = File(p.join(project, 'pubspec.yaml'));
      final hasPubspec = pubspec.existsSync();
      reqs.add(
        McpRequirement(
          id: 'pubspec',
          label: 'pubspec.yaml',
          ok: hasPubspec,
          detail: hasPubspec ? 'Found' : 'Missing pubspec.yaml',
          fixHint: 'Open a valid Flutter project',
        ),
      );
    }

    final cursorDir = _cursorDir();
    reqs.add(
      McpRequirement(
        id: 'cursor_dir',
        label: 'Cursor config dir',
        ok: cursorDir != null,
        detail: cursorDir ?? 'HOME not set — cannot write ~/.cursor/mcp.json',
        fixHint: 'Ensure HOME is set so Patroller can write MCP config',
      ),
    );

    return reqs;
  }

  bool allRequiredOk(List<McpRequirement> reqs) {
    const required = {
      'dart',
      'patrol_mcp',
      'marionette_mcp',
      'project',
      'cursor_dir',
    };
    return reqs
        .where((r) => required.contains(r.id))
        .every((r) => r.ok);
  }

  Future<McpToolStatus> resolvePatrolMcp() async {
    final dart = resolveExecutable('dart');
    // Preferred: global run (works even without bin shim).
    try {
      final result = await Process.run(
        dart,
        ['pub', 'global', 'run', 'patrol_mcp:patrol_mcp', '--version'],
        environment: developerToolEnv(),
      );
      if (result.exitCode == 0) {
        final out = '${result.stdout}${result.stderr}'.trim();
        return McpToolStatus(
          name: 'patrol_mcp',
          available: true,
          command: '$dart pub global run patrol_mcp:patrol_mcp',
          version: out.isEmpty ? null : out,
        );
      }
    } catch (_) {}

    // Fallback: pub-cache bin shim if present.
    final home = Platform.environment['HOME'];
    if (home != null) {
      final shim = p.join(home, '.pub-cache', 'bin', 'patrol_mcp');
      if (File(shim).existsSync()) {
        return McpToolStatus(
          name: 'patrol_mcp',
          available: true,
          command: shim,
          version: await _versionOf(shim, const ['--version']),
        );
      }
    }

    return const McpToolStatus(
      name: 'patrol_mcp',
      available: false,
      command: 'dart pub global run patrol_mcp:patrol_mcp',
      error: 'Not installed',
    );
  }

  Future<McpToolStatus> resolveMarionetteMcp() async {
    final resolved = resolveExecutable('marionette_mcp');
    if (File(resolved).existsSync() || resolved == 'marionette_mcp') {
      final version = await _versionOf(resolved, const ['--version']);
      if (version != null || File(resolved).existsSync()) {
        final probe = await Process.run(
          resolved,
          const ['--version'],
          environment: developerToolEnv(),
        );
        if (probe.exitCode == 0) {
          return McpToolStatus(
            name: 'marionette_mcp',
            available: true,
            command: File(resolved).existsSync()
                ? resolved
                : resolveExecutable('marionette_mcp'),
            version: '${probe.stdout}${probe.stderr}'.trim(),
          );
        }
      }
    }

    final dart = resolveExecutable('dart');
    try {
      final result = await Process.run(
        dart,
        ['pub', 'global', 'run', 'marionette_mcp:marionette_mcp', '--version'],
        environment: developerToolEnv(),
      );
      if (result.exitCode == 0) {
        return McpToolStatus(
          name: 'marionette_mcp',
          available: true,
          command: '$dart pub global run marionette_mcp:marionette_mcp',
          version: '${result.stdout}${result.stderr}'.trim(),
        );
      }
    } catch (_) {}

    return const McpToolStatus(
      name: 'marionette_mcp',
      available: false,
      command: 'marionette_mcp',
      error: 'Not installed',
    );
  }

  /// Install or update [patrol_mcp] globally on this machine.
  Future<McpInstallResult> installPatrolMcp() async {
    return activatePackage(patrolPackage);
  }

  /// Install or update [marionette_mcp] globally on this machine.
  Future<McpInstallResult> installMarionetteMcp() async {
    return activatePackage(marionettePackage);
  }

  /// Install or update both MCP packages globally.
  Future<List<McpInstallResult>> installOrUpdateBoth() async {
    final results = <McpInstallResult>[];
    results.add(await installPatrolMcp());
    results.add(await installMarionetteMcp());
    return results;
  }

  /// `dart pub global activate <package>` — machine-wide, never project-local.
  Future<McpInstallResult> activatePackage(String package) async {
    final dart = resolveExecutable('dart');
    try {
      final result = await Process.run(
        dart,
        ['pub', 'global', 'activate', package],
        environment: developerToolEnv(),
      );
      if (result.exitCode != 0) {
        final err = '${result.stderr}${result.stdout}'.trim();
        return McpInstallResult(
          package: package,
          ok: false,
          message: err.isEmpty ? 'Failed to activate $package' : err,
        );
      }

      final version = await _readGlobalPackageVersion(package);
      final out = '${result.stdout}'.trim();
      return McpInstallResult(
        package: package,
        ok: true,
        version: version,
        message: version != null
            ? 'Installed $package $version (global on this machine)'
            : (out.isEmpty
                ? 'Installed $package (global on this machine)'
                : out),
      );
    } catch (e) {
      return McpInstallResult(
        package: package,
        ok: false,
        message: e.toString(),
      );
    }
  }

  Future<String?> _readGlobalPackageVersion(String package) async {
    try {
      final dart = resolveExecutable('dart');
      final result = await Process.run(
        dart,
        ['pub', 'global', 'list'],
        environment: developerToolEnv(),
      );
      if (result.exitCode != 0) return null;
      final lines = '${result.stdout}'.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        // e.g. "patrol_mcp 0.1.4"
        if (trimmed.startsWith('$package ')) {
          return trimmed.substring(package.length).trim();
        }
        if (trimmed.startsWith('$package-')) {
          // unlikely; keep defensive
          return trimmed;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Writes wrappers + merges ~/.cursor/mcp.json, then probes both servers.
  Future<McpRoutineResult> startAgentRoutine({
    required String projectPath,
    required String projectName,
    String? patrolFlags,
    bool verify = true,
  }) async {
    final reqs = await checkRequirements(projectPath: projectPath);
    if (!allRequiredOk(reqs)) {
      final missing = reqs.where((r) => !r.ok).map((r) => r.label).join(', ');
      return McpRoutineResult(
        ok: false,
        message: 'Requirements not met: $missing',
      );
    }

    final cursorDir = _cursorDir();
    if (cursorDir == null) {
      return const McpRoutineResult(
        ok: false,
        message: 'Cannot resolve ~/.cursor directory',
      );
    }

    final dir = Directory(cursorDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final slug = _slug(projectName);
    final wrapperPath = p.join(cursorDir, 'run-patrol-$slug');
    final dart = resolveExecutable('dart');
    final flutter = resolveExecutable('flutter');

    // Use the resolved dart binary directly — never `fvm dart` here.
    // FVM can prompt interactively (version cache mismatches), which hangs
    // Cursor's stdio MCP transport and breaks Patrol MCP discovery.
    final wrapper = buildPatrolWrapperScript(
      projectPath: projectPath,
      dartExecutable: dart,
      flutterExecutable: flutter,
    );
    await File(wrapperPath).writeAsString(wrapper);
    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', wrapperPath]);
    }

    final marionette = await resolveMarionetteMcp();
    final marionetteLaunch = _marionetteLaunch(marionette);
    final mcpPath = p.join(cursorDir, 'mcp.json');
    final existing = await _readJsonMap(mcpPath);
    final servers = Map<String, dynamic>.from(
      (existing['mcpServers'] as Map?)?.cast<String, dynamic>() ?? {},
    );

    servers['patrol'] = {
      'command': wrapperPath,
      'env': {
        'PROJECT_ROOT': projectPath,
        if (patrolFlags != null && patrolFlags.isNotEmpty)
          'PATROL_FLAGS': patrolFlags,
        'SHOW_TERMINAL': 'false',
        'CI': 'true',
      },
    };
    servers['marionette'] = {
      'command': marionetteLaunch.command,
      'args': marionetteLaunch.args,
    };

    final payload = {
      ...existing,
      'mcpServers': servers,
    };
    await File(mcpPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );

    McpServerProbe? patrolProbe;
    McpServerProbe? marionetteProbe;
    if (verify) {
      final probes = await verifyConfiguredServers(
        projectPath: projectPath,
        patrolFlags: patrolFlags,
        wrapperPath: wrapperPath,
        marionetteCommand: marionetteLaunch.command,
        marionetteArgs: marionetteLaunch.args,
      );
      patrolProbe = probes.patrol;
      marionetteProbe = probes.marionette;
    }

    final bothOk = !verify ||
        ((patrolProbe?.ok ?? false) && (marionetteProbe?.ok ?? false));
    final message = !verify
        ? 'MCP config written. Restart Cursor (or reload MCP servers).'
        : bothOk
            ? 'Patrol MCP + Marionette MCP triggered successfully. '
                'Reload MCP servers in Cursor to use them.'
            : 'MCP config written, but server probes failed. '
                'See Patrol / Marionette status below.';

    return McpRoutineResult(
      ok: bothOk,
      message: message,
      wrapperPath: wrapperPath,
      mcpConfigPath: mcpPath,
      patrolProbe: patrolProbe,
      marionetteProbe: marionetteProbe,
    );
  }

  /// Shell wrapper content for Patrol MCP (non-interactive; no fvm).
  String buildPatrolWrapperScript({
    required String projectPath,
    required String dartExecutable,
    required String flutterExecutable,
  }) {
    return '''
#!/usr/bin/env sh
set -e

export PROJECT_ROOT="\${PROJECT_ROOT:-$projectPath}"
export PATROL_FLUTTER_COMMAND="\${PATROL_FLUTTER_COMMAND:-$flutterExecutable}"
export CI="\${CI:-true}"
export FVM_CI="\${FVM_CI:-true}"

cd "\$PROJECT_ROOT"

exec "$dartExecutable" pub global run patrol_mcp:patrol_mcp "\$@"
''';
  }

  /// Launches each configured MCP server and completes initialize.
  Future<({McpServerProbe patrol, McpServerProbe marionette})>
      verifyConfiguredServers({
    required String projectPath,
    String? patrolFlags,
    String? wrapperPath,
    String? marionetteCommand,
    List<String>? marionetteArgs,
  }) async {
    final patrol = await triggerPatrolMcp(
      projectPath: projectPath,
      patrolFlags: patrolFlags,
      wrapperPath: wrapperPath,
    );
    final marionette = await triggerMarionetteMcp(
      command: marionetteCommand,
      args: marionetteArgs,
    );
    return (patrol: patrol, marionette: marionette);
  }

  /// Starts Patrol MCP and completes the MCP initialize handshake.
  Future<McpServerProbe> triggerPatrolMcp({
    required String projectPath,
    String? patrolFlags,
    String? wrapperPath,
  }) async {
    final env = <String, String>{
      ...developerToolEnv(),
      'PROJECT_ROOT': projectPath,
      'SHOW_TERMINAL': 'false',
      'CI': 'true',
      'FVM_CI': 'true',
      if (patrolFlags != null && patrolFlags.isNotEmpty)
        'PATROL_FLAGS': patrolFlags,
    };

    if (wrapperPath != null && File(wrapperPath).existsSync()) {
      return _probeStdioServer(
        id: 'patrol',
        label: 'Patrol MCP',
        executable: wrapperPath,
        args: const [],
        environment: env,
      );
    }

    final dart = resolveExecutable('dart');
    return _probeStdioServer(
      id: 'patrol',
      label: 'Patrol MCP',
      executable: dart,
      args: const ['pub', 'global', 'run', 'patrol_mcp:patrol_mcp'],
      environment: env,
    );
  }

  /// Starts Marionette MCP and completes the MCP initialize handshake.
  Future<McpServerProbe> triggerMarionetteMcp({
    String? command,
    List<String>? args,
  }) async {
    final launch = command != null
        ? (command: command, args: args ?? const <String>[])
        : _marionetteLaunch(await resolveMarionetteMcp());

    return _probeStdioServer(
      id: 'marionette',
      label: 'Marionette MCP',
      executable: launch.command,
      args: launch.args,
      environment: developerToolEnv(),
    );
  }

  ({String command, List<String> args}) _marionetteLaunch(
    McpToolStatus marionette,
  ) {
    final home = Platform.environment['HOME'];
    if (home != null) {
      final shim = p.join(home, '.pub-cache', 'bin', 'marionette_mcp');
      if (File(shim).existsSync()) {
        return (command: shim, args: const <String>[]);
      }
    }

    if (marionette.command.contains('pub global run')) {
      return (
        command: resolveExecutable('dart'),
        args: const [
          'pub',
          'global',
          'run',
          'marionette_mcp:marionette_mcp',
        ],
      );
    }

    return (command: marionette.command, args: const <String>[]);
  }

  Future<McpServerProbe> _probeStdioServer({
    required String id,
    required String label,
    required String executable,
    required List<String> args,
    required Map<String, String> environment,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    Process? process;
    try {
      process = await Process.start(
        executable,
        args,
        environment: environment,
        workingDirectory: environment['PROJECT_ROOT'],
      );

      final init = jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {
          'protocolVersion': '2024-11-05',
          'capabilities': <String, dynamic>{},
          'clientInfo': {'name': 'patroller', 'version': '1.0.0'},
        },
      });
      process.stdin.writeln(init);
      await process.stdin.flush();

      final line = await process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(timeout);

      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        return McpServerProbe(
          id: id,
          label: label,
          ok: false,
          detail: 'Unexpected initialize response',
        );
      }

      final error = decoded['error'];
      if (error != null) {
        return McpServerProbe(
          id: id,
          label: label,
          ok: false,
          detail: 'Initialize error: $error',
        );
      }

      final result = decoded['result'];
      if (result is! Map) {
        return McpServerProbe(
          id: id,
          label: label,
          ok: false,
          detail: 'Initialize missing result',
        );
      }

      final serverInfo = result['serverInfo'];
      String? name;
      String? version;
      if (serverInfo is Map) {
        name = serverInfo['name']?.toString();
        version = serverInfo['version']?.toString();
      }

      final detail = [
        if (name != null) name,
        if (version != null) 'v$version',
        'initialize ok',
      ].join(' · ');

      return McpServerProbe(
        id: id,
        label: label,
        ok: true,
        detail: detail,
        serverName: name,
        serverVersion: version,
      );
    } on TimeoutException {
      return McpServerProbe(
        id: id,
        label: label,
        ok: false,
        detail: 'Timed out waiting for initialize (is the server hung?)',
      );
    } catch (e) {
      return McpServerProbe(
        id: id,
        label: label,
        ok: false,
        detail: e.toString(),
      );
    } finally {
      process?.kill();
      // Drain briefly so the process can exit cleanly.
      try {
        await process?.exitCode.timeout(const Duration(milliseconds: 500));
      } catch (_) {}
    }
  }

  /// Writes a filled agent prompt under `~/.cursor/patroller-prompts/` and
  /// returns the absolute path + body (for clipboard hand-off to Cursor).
  Future<({String path, String text})> writeAgentPrompt({
    required AgentPromptId id,
    required AgentPromptContext context,
  }) async {
    final cursorDir = _cursorDir();
    if (cursorDir == null) {
      throw StateError('HOME not set — cannot write agent prompt');
    }
    final dir = Directory(p.join(cursorDir, 'patroller-prompts'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final slug = _slug(context.projectName);
    final fileName = switch (id) {
      AgentPromptId.marionetteCoverageExploration =>
        'marionette-coverage-$slug.md',
    };
    final path = p.join(dir.path, fileName);
    final text = renderAgentPrompt(id, context);
    await File(path).writeAsString('$text\n');
    return (path: path, text: text);
  }

  /// Bind MCP to the open project, then materialize the agent prompt.
  Future<AgentPromptRoutineResult> startAgentPromptRoutine({
    required AgentPromptId id,
    required AgentPromptContext context,
    String? patrolFlags,
    bool verifyMcp = true,
  }) async {
    final mcp = await startAgentRoutine(
      projectPath: context.projectPath,
      projectName: context.projectName,
      patrolFlags: patrolFlags,
      verify: verifyMcp,
    );
    if (!mcp.ok) {
      return AgentPromptRoutineResult(
        ok: false,
        message: mcp.message,
        mcpConfigPath: mcp.mcpConfigPath,
        wrapperPath: mcp.wrapperPath,
      );
    }

    try {
      final written = await writeAgentPrompt(id: id, context: context);
      final title = agentPromptCatalog
          .firstWhere((m) => m.id == id)
          .title;
      return AgentPromptRoutineResult(
        ok: true,
        message:
            '$title ready. MCP config written; prompt saved and ready to paste '
            'into Cursor agent chat.\n${written.path}',
        promptPath: written.path,
        promptText: written.text,
        mcpConfigPath: mcp.mcpConfigPath,
        wrapperPath: mcp.wrapperPath,
      );
    } catch (e) {
      return AgentPromptRoutineResult(
        ok: false,
        message: 'MCP config OK, but failed to write agent prompt: $e',
        mcpConfigPath: mcp.mcpConfigPath,
        wrapperPath: mcp.wrapperPath,
      );
    }
  }

  String globalMcpSnippet({
    required String projectPath,
    required String projectName,
    String? patrolFlags,
  }) {
    final home = Platform.environment['HOME'] ?? '/Users/<you>';
    final slug = _slug(projectName);
    final wrapper = p.join(home, '.cursor', 'run-patrol-$slug');
    final marionette = p.join(home, '.pub-cache', 'bin', 'marionette_mcp');
    final flags = patrolFlags ?? '';
    return '''
{
  "mcpServers": {
    "patrol": {
      "command": "$wrapper",
      "env": {
        "PROJECT_ROOT": "$projectPath",
        "PATROL_FLAGS": "$flags",
        "SHOW_TERMINAL": "false",
        "CI": "true"
      }
    },
    "marionette": {
      "command": "$marionette",
      "args": []
    }
  }
}
'''.trim();
  }

  String? _cursorDir() {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return null;
    return p.join(home, '.cursor');
  }

  String _slug(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  Future<Map<String, dynamic>> _readJsonMap(String path) async {
    final file = File(path);
    if (!file.existsSync()) return {};
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    return {};
  }

  Future<McpToolStatus> _probeTool(String name, List<String> args) async {
    final exe = resolveExecutable(name);
    try {
      final result = await Process.run(
        exe,
        args,
        environment: developerToolEnv(),
      );
      final out = '${result.stdout}${result.stderr}'.trim();
      return McpToolStatus(
        name: name,
        available: result.exitCode == 0,
        command: exe,
        version: out.isEmpty ? null : out,
        error: result.exitCode == 0 ? null : out,
      );
    } catch (e) {
      return McpToolStatus(
        name: name,
        available: false,
        command: exe,
        error: e.toString(),
      );
    }
  }

  Future<String?> _versionOf(String exe, List<String> args) async {
    try {
      final result = await Process.run(
        exe,
        args,
        environment: developerToolEnv(),
      );
      if (result.exitCode != 0) return null;
      final out = '${result.stdout}${result.stderr}'.trim();
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }
}
