import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/agent_prompts.dart';
import '../services/cli_env.dart';
import '../services/mcp_service.dart';
import 'app_provider.dart';
import 'runner_provider.dart';
import 'settings_provider.dart';

class McpState {
  const McpState({
    this.requirements = const [],
    this.checking = false,
    this.installing = false,
    /// Which package is installing: `patrol_mcp`, `marionette_mcp`, or `both`.
    this.installingPackage,
    this.starting = false,
    this.lastMessage,
    this.lastError,
    this.wrapperPath,
    this.mcpConfigPath,
    this.agentPromptPath,
    this.agentPromptText,
    this.lastAgentPromptId,
  });

  final List<McpRequirement> requirements;
  final bool checking;
  final bool installing;
  final String? installingPackage;
  final bool starting;
  final String? lastMessage;
  final String? lastError;
  final String? wrapperPath;
  final String? mcpConfigPath;
  final String? agentPromptPath;
  final String? agentPromptText;
  final AgentPromptId? lastAgentPromptId;

  bool get ready =>
      requirements.isNotEmpty &&
      McpService().allRequiredOk(requirements);

  bool get machineMcpReady {
    if (requirements.isEmpty) return false;
    return requirements
        .where((r) => r.id == 'patrol_mcp' || r.id == 'marionette_mcp')
        .every((r) => r.ok);
  }

  bool get hasMissingMachineMcp => requirements.any(
        (r) =>
            (r.id == 'patrol_mcp' || r.id == 'marionette_mcp') && !r.ok,
      );

  McpRequirement? requirement(String id) {
    for (final r in requirements) {
      if (r.id == id) return r;
    }
    return null;
  }

  McpState copyWith({
    List<McpRequirement>? requirements,
    bool? checking,
    bool? installing,
    String? installingPackage,
    bool? starting,
    String? lastMessage,
    String? lastError,
    String? wrapperPath,
    String? mcpConfigPath,
    String? agentPromptPath,
    String? agentPromptText,
    AgentPromptId? lastAgentPromptId,
    bool clearMessage = false,
    bool clearError = false,
    bool clearInstallingPackage = false,
    bool clearAgentPrompt = false,
  }) {
    return McpState(
      requirements: requirements ?? this.requirements,
      checking: checking ?? this.checking,
      installing: installing ?? this.installing,
      installingPackage: clearInstallingPackage
          ? null
          : (installingPackage ?? this.installingPackage),
      starting: starting ?? this.starting,
      lastMessage: clearMessage ? null : (lastMessage ?? this.lastMessage),
      lastError: clearError ? null : (lastError ?? this.lastError),
      wrapperPath: wrapperPath ?? this.wrapperPath,
      mcpConfigPath: mcpConfigPath ?? this.mcpConfigPath,
      agentPromptPath: clearAgentPrompt
          ? null
          : (agentPromptPath ?? this.agentPromptPath),
      agentPromptText: clearAgentPrompt
          ? null
          : (agentPromptText ?? this.agentPromptText),
      lastAgentPromptId: clearAgentPrompt
          ? null
          : (lastAgentPromptId ?? this.lastAgentPromptId),
    );
  }
}

class McpNotifier extends StateNotifier<McpState> {
  McpNotifier(this._ref) : super(const McpState());

  final Ref _ref;
  final _service = McpService();

  Future<void> refresh() async {
    state = state.copyWith(checking: true, clearError: true);
    try {
      final project = _ref.read(appProvider).currentProject;
      final reqs = await _service.checkRequirements(
        projectPath: project?.projectPath,
      );
      state = state.copyWith(requirements: reqs, checking: false);
    } catch (e) {
      state = state.copyWith(
        checking: false,
        lastError: e.toString(),
      );
    }
  }

  /// Install only packages that are currently missing (legacy entry point).
  Future<void> installMissing() async {
    final needPatrol =
        state.requirements.any((r) => r.id == 'patrol_mcp' && !r.ok);
    final needMarionette =
        state.requirements.any((r) => r.id == 'marionette_mcp' && !r.ok);

    if (!needPatrol && !needMarionette) {
      state = state.copyWith(
        lastMessage: 'Both MCP packages are already installed on this machine',
        clearError: true,
      );
      return;
    }

    await _runInstalls(
      installPatrol: needPatrol,
      installMarionette: needMarionette,
      packageLabel: 'missing',
    );
  }

  /// Install or update both packages to the latest pub.dev versions (machine-wide).
  Future<void> installOrUpdateBoth() async {
    await _runInstalls(
      installPatrol: true,
      installMarionette: true,
      packageLabel: 'both',
    );
  }

  Future<void> installPatrol() async {
    await _runInstalls(
      installPatrol: true,
      installMarionette: false,
      packageLabel: McpService.patrolPackage,
    );
  }

  Future<void> installMarionette() async {
    await _runInstalls(
      installPatrol: false,
      installMarionette: true,
      packageLabel: McpService.marionettePackage,
    );
  }

  Future<void> _runInstalls({
    required bool installPatrol,
    required bool installMarionette,
    required String packageLabel,
  }) async {
    state = state.copyWith(
      installing: true,
      installingPackage: packageLabel,
      clearError: true,
      clearMessage: true,
    );
    try {
      final results = <McpInstallResult>[];
      if (installPatrol) {
        results.add(await _service.installPatrolMcp());
      }
      if (installMarionette) {
        results.add(await _service.installMarionetteMcp());
      }

      await refresh();

      final failed = results.where((r) => !r.ok).toList();
      final ok = results.where((r) => r.ok).toList();
      final okMsg = ok.map((r) => r.message).join('\n');
      final errMsg = failed.map((r) => '${r.package}: ${r.message}').join('\n');

      state = state.copyWith(
        installing: false,
        clearInstallingPackage: true,
        lastMessage: ok.isEmpty ? null : okMsg,
        lastError: failed.isEmpty ? null : errMsg,
      );
    } catch (e) {
      state = state.copyWith(
        installing: false,
        clearInstallingPackage: true,
        lastError: e.toString(),
      );
    }
  }

  /// Writes Cursor MCP config for the **currently open project**.
  /// MCP packages themselves stay machine-global.
  Future<void> startRoutine() async {
    final project = _ref.read(appProvider).currentProject;
    if (project == null) {
      state = state.copyWith(
        lastError:
            'Open a project first — MCP packages are global, but the routine '
            'binds Patrol MCP to the selected project',
      );
      return;
    }

    state = state.copyWith(starting: true, clearError: true, clearMessage: true);
    try {
      await refresh();
      if (!state.ready) {
        state = state.copyWith(
          starting: false,
          lastError:
              'Fulfill all requirements first. Install missing MCP packages '
              'on this machine, then open a valid project.',
        );
        return;
      }

      final settings = _ref.read(settingsProvider).settings;
      final flags = settings.extraPatrolArgs.isEmpty
          ? null
          : settings.extraPatrolArgs.join(' ');

      final result = await _service.startAgentRoutine(
        projectPath: project.projectPath,
        projectName: project.projectName,
        patrolFlags: flags,
      );

      state = state.copyWith(
        starting: false,
        lastMessage: result.ok ? result.message : null,
        lastError: result.ok ? null : result.message,
        wrapperPath: result.wrapperPath,
        mcpConfigPath: result.mcpConfigPath,
      );
    } catch (e) {
      state = state.copyWith(starting: false, lastError: e.toString());
    }
  }

  String configSnippet() {
    final project = _ref.read(appProvider).currentProject;
    if (project == null) return '';
    final settings = _ref.read(settingsProvider).settings;
    final flags = settings.extraPatrolArgs.join(' ');
    return _service.globalMcpSnippet(
      projectPath: project.projectPath,
      projectName: project.projectName,
      patrolFlags: flags.isEmpty ? null : flags,
    );
  }

  AgentPromptContext? promptContext() {
    final project = _ref.read(appProvider).currentProject;
    if (project == null) return null;
    final settings = _ref.read(settingsProvider).settings;
    final device = _ref.read(runnerProvider).selectedDevice;
    final flutter = resolveExecutable(
      'flutter',
      configuredPath: settings.flutterPath,
    );
    return buildAgentPromptContext(
      projectName: project.projectName,
      projectPath: project.projectPath,
      flutterExecutable: flutter,
      deviceName: device?.name,
      patrolTestDir: project.patrolTestDir.isNotEmpty
          ? project.patrolTestDir
          : settings.testDirectory,
    );
  }

  /// Filled prompt text only (no MCP bind). Empty if no project open.
  String? buildPrompt(AgentPromptId id) {
    final ctx = promptContext();
    if (ctx == null) return null;
    return renderAgentPrompt(id, ctx);
  }

  /// Copy-ready: write prompt file without rebinding MCP.
  Future<String?> preparePromptOnly(AgentPromptId id) async {
    final ctx = promptContext();
    if (ctx == null) {
      state = state.copyWith(lastError: 'Open a project first');
      return null;
    }
    try {
      final written = await _service.writeAgentPrompt(id: id, context: ctx);
      state = state.copyWith(
        agentPromptPath: written.path,
        agentPromptText: written.text,
        lastAgentPromptId: id,
        lastMessage: 'Agent prompt written to ${written.path}',
        clearError: true,
      );
      return written.text;
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
      return null;
    }
  }

  /// Full trigger: bind Patrol + Marionette MCP to the open project, write the
  /// agent prompt under ~/.cursor/patroller-prompts/, and keep text for clipboard.
  Future<String?> startAgentPromptRoutine(AgentPromptId id) async {
    final project = _ref.read(appProvider).currentProject;
    if (project == null) {
      state = state.copyWith(
        lastError:
            'Open a project first — the agent prompt is filled from the '
            'selected project and simulator',
      );
      return null;
    }

    final ctx = promptContext();
    if (ctx == null) {
      state = state.copyWith(lastError: 'Could not build agent prompt context');
      return null;
    }

    state = state.copyWith(
      starting: true,
      clearError: true,
      clearMessage: true,
      clearAgentPrompt: true,
    );
    try {
      await refresh();
      if (!state.ready) {
        state = state.copyWith(
          starting: false,
          lastError:
              'Install MCP packages and open a valid project before starting '
              'the agent prompt routine',
        );
        return null;
      }

      final settings = _ref.read(settingsProvider).settings;
      final flags = settings.extraPatrolArgs.isEmpty
          ? null
          : settings.extraPatrolArgs.join(' ');

      final result = await _service.startAgentPromptRoutine(
        id: id,
        context: ctx,
        patrolFlags: flags,
      );

      state = state.copyWith(
        starting: false,
        lastMessage: result.ok ? result.message : null,
        lastError: result.ok ? null : result.message,
        wrapperPath: result.wrapperPath,
        mcpConfigPath: result.mcpConfigPath,
        agentPromptPath: result.promptPath,
        agentPromptText: result.promptText,
        lastAgentPromptId: id,
      );
      return result.ok ? result.promptText : null;
    } catch (e) {
      state = state.copyWith(starting: false, lastError: e.toString());
      return null;
    }
  }
}

final mcpProvider = StateNotifierProvider<McpNotifier, McpState>(
  (ref) => McpNotifier(ref),
);
