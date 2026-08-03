import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/agent_prompts.dart';
import '../../domain/routine_models.dart';
import '../../providers/app_provider.dart';
import '../../providers/mcp_provider.dart';
import '../../providers/routine_provider.dart';
import '../../services/mcp_service.dart';
import '../../widgets/accessible_icon_button.dart';

/// Agent workbench:
/// - Install / update Patrol MCP + Marionette MCP **on this machine**
///   (global `dart pub global activate` — never into the Flutter project pubspec).
/// - Three separate paths: Autonomous (Patroller drives), Bind MCP (setup only),
///   or Copy prompt (DIY — paste into your own AI).
class AgentWorkbenchPanel extends ConsumerStatefulWidget {
  const AgentWorkbenchPanel({super.key});

  @override
  ConsumerState<AgentWorkbenchPanel> createState() =>
      _AgentWorkbenchPanelState();
}

class _AgentWorkbenchPanelState extends ConsumerState<AgentWorkbenchPanel> {
  Future<void> _confirmRemoveDependency(BuildContext context, String package) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove $package?'),
        content: Text(
          'Patroller will run `flutter pub remove $package` in the selected project. '
          'This updates pubspec.yaml and may update pubspec.lock.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remove')),
        ],
      ),
    );
    if (remove == true && mounted) {
      await ref.read(routineProvider.notifier).removeDependency(package);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mcpProvider.notifier).refresh();
      ref.read(routineProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final project = ref.watch(appProvider).currentProject;
    final mcp = ref.watch(mcpProvider);
    final routine = ref.watch(routineProvider);
    final busy = mcp.installing || mcp.starting || mcp.checking || routine.busy;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Heading('Agent workbench'),
          const SizedBox(height: 6),
          Text(
            'Three separate paths — pick one (not steps in a pipeline). '
            'Install MCP tools on this machine first if you need them.',
            style: TextStyle(fontSize: 12, color: p.textMuted, height: 1.45),
          ),
          const SizedBox(height: 16),

          _RoutineCard(
            state: routine,
            onRefresh: () => ref.read(routineProvider.notifier).refresh(),
            onGoalChanged: (value) => ref.read(routineProvider.notifier).setGoal(value),
            onModelChanged: (value) => ref.read(routineProvider.notifier).selectModel(value),
            onPubGet: () => ref.read(routineProvider.notifier).pubGet(),
            onInstallOpenCode: () => ref.read(routineProvider.notifier).installOpenCode(),
            onRemoveDependency: (value) => _confirmRemoveDependency(context, value),
            onToggleDirtyWorktree: (value) => ref.read(routineProvider.notifier).toggleAllowDirtyWorktree(value),
            onRespondPermission: (id, allow) => ref.read(routineProvider.notifier).respondPermission(id, allow),
            onStart: () => ref.read(routineProvider.notifier).prepareAndStart(),
            onApprove: () => ref.read(routineProvider.notifier).prepareAndStart(approved: true),
            onStop: () => ref.read(routineProvider.notifier).stop(),
          ),
          const SizedBox(height: 16),

          // ── Machine-level install ──────────────────────────────────────
          Row(
            children: [
              const _Heading('1. Install tools on this machine'),
              const Spacer(),
              TextButton.icon(
                onPressed: mcp.checking
                    ? null
                    : () => ref.read(mcpProvider.notifier).refresh(),
                icon: mcp.checking
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    : const Icon(Icons.refresh, size: 14),
                label: const Text('Recheck', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: PatrolColors.sky400,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Puts Patrol + Marionette MCP in your shared toolbox '
            '(dart pub global activate). Not your app pubspec.',
            style: TextStyle(fontSize: 11, color: p.textMuted, height: 1.4),
          ),
          const SizedBox(height: 10),
          if (mcp.requirements.isEmpty && mcp.checking)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            _MachinePackageCard(
              req: mcp.requirement('dart'),
              title: 'Dart CLI',
              subtitle: 'Required to install and run MCP packages',
              actionLabel: null,
              installing: false,
              enabled: false,
              onInstall: null,
            ),
            const SizedBox(height: 8),
            _MachinePackageCard(
              req: mcp.requirement('patrol_mcp'),
              title: 'Patrol MCP',
              subtitle:
                  'Global package for patrol develop, native-tree, screenshot, run',
              actionLabel: _installLabel(
                mcp,
                packageId: McpService.patrolPackage,
                installed: mcp.requirement('patrol_mcp')?.ok ?? false,
              ),
              installing: mcp.installing &&
                  (mcp.installingPackage == McpService.patrolPackage ||
                      mcp.installingPackage == 'both' ||
                      mcp.installingPackage == 'missing'),
              enabled: !busy && (mcp.requirement('dart')?.ok ?? false),
              onInstall: () => ref.read(mcpProvider.notifier).installPatrol(),
            ),
            const SizedBox(height: 8),
            _MachinePackageCard(
              req: mcp.requirement('marionette_mcp'),
              title: 'Marionette MCP',
              subtitle:
                  'Global package for Flutter widget inspect / tap on debug apps',
              actionLabel: _installLabel(
                mcp,
                packageId: McpService.marionettePackage,
                installed: mcp.requirement('marionette_mcp')?.ok ?? false,
              ),
              installing: mcp.installing &&
                  (mcp.installingPackage == McpService.marionettePackage ||
                      mcp.installingPackage == 'both' ||
                      mcp.installingPackage == 'missing'),
              enabled: !busy && (mcp.requirement('dart')?.ok ?? false),
              onInstall: () =>
                  ref.read(mcpProvider.notifier).installMarionette(),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionChip(
                label: mcp.installing &&
                        (mcp.installingPackage == 'both' ||
                            mcp.installingPackage == 'missing')
                    ? 'Installing…'
                    : mcp.hasMissingMachineMcp
                        ? 'Install missing MCP'
                        : 'Install / update both',
                icon: Icons.download_outlined,
                color: PatrolColors.amber,
                enabled: !busy && (mcp.requirement('dart')?.ok ?? true),
                onPressed: () {
                  if (mcp.hasMissingMachineMcp) {
                    ref.read(mcpProvider.notifier).installMissing();
                  } else {
                    ref.read(mcpProvider.notifier).installOrUpdateBoth();
                  }
                },
              ),
              if (!mcp.hasMissingMachineMcp && mcp.machineMcpReady)
                _ActionChip(
                  label: 'Update both to latest',
                  icon: Icons.system_update_alt_outlined,
                  color: PatrolColors.sky400,
                  enabled: !busy,
                  onPressed: () =>
                      ref.read(mcpProvider.notifier).installOrUpdateBoth(),
                ),
            ],
          ),

          if (mcp.lastError != null) ...[
            const SizedBox(height: 10),
            _Banner(text: mcp.lastError!, error: true),
          ],
          if (mcp.lastMessage != null) ...[
            const SizedBox(height: 10),
            _Banner(text: mcp.lastMessage!, error: false),
          ],

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // ── Project binding ────────────────────────────────────────────
          const _Heading('2. Plug MCP into this project'),
          const SizedBox(height: 4),
          Text(
            'Setup only — like plugging tools into a toy. Wires machine MCP '
            'to the open project so your own AI can use them. Does not touch '
            'pubspec and does not run an agent.',
            style: TextStyle(fontSize: 11, color: p.textMuted, height: 1.4),
          ),
          const SizedBox(height: 10),

          if (project == null)
            _Banner(
              text:
                  'Open a Flutter project to plug MCP into it. '
                  'You can still install tools above without a project.',
              error: false,
            )
          else ...[
            ...mcp.requirements
                .where((r) =>
                    r.id == 'project' ||
                    r.id == 'pubspec' ||
                    r.id == 'opencode')
                .map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _ReqRow(req: r),
                    )),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.projectName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    project.projectPath,
                    style: TextStyle(fontSize: 10, color: p.textMuted),
                  ),
                  if (project.hasPatrol) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Patrol tests: ${project.patrolTestDir}/',
                      style: const TextStyle(
                        fontSize: 10,
                        color: PatrolColors.psPassed,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionChip(
                  label: mcp.starting ? 'Binding…' : 'Bind MCP to this project',
                  icon: Icons.play_arrow_rounded,
                  color: PatrolColors.violet400,
                  enabled: mcp.ready && !busy,
                  onPressed: () =>
                      ref.read(mcpProvider.notifier).startRoutine(),
                ),
              ],
            ),
            if (mcp.mcpConfigPath != null) ...[
              const SizedBox(height: 8),
              Text(
                'Config: ${mcp.mcpConfigPath}',
                style: TextStyle(fontSize: 10, color: p.textMuted),
              ),
              if (mcp.wrapperPath != null)
                Text(
                  'Wrapper: ${mcp.wrapperPath}',
                  style: TextStyle(fontSize: 10, color: p.textMuted),
                ),
            ],
            const SizedBox(height: 14),
            _CopyTile(
              label: 'Global MCP config template',
              detail: '~/.config/opencode/opencode.jsonc (Patrol + Marionette)',
              onCopy: () {
                final snippet = ref.read(mcpProvider.notifier).configSnippet();
                _copy(context, snippet);
              },
            ),
            const SizedBox(height: 8),
            _CopyTile(
              label: 'Bootstrap test path',
              detail: 'patrol_test/agent/bootstrap_home_test.dart',
              onCopy: () =>
                  _copy(context, 'patrol_test/agent/bootstrap_home_test.dart'),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // ── Agent prompt routines ─────────────────────────────────
            const _Heading('3. Copy a prompt for your AI'),
            const SizedBox(height: 4),
            Text(
              'Like a homework sheet: Patroller fills a prompt from this '
              'project. You paste it into OpenCode or your AI IDE. '
              'Patroller does not run that agent.',
              style: TextStyle(fontSize: 11, color: p.textMuted, height: 1.4),
            ),
            const SizedBox(height: 10),
            ...agentPromptCatalog.map((meta) {
              final isThis =
                  mcp.lastAgentPromptId == meta.id && mcp.agentPromptPath != null;
              final launching = mcp.starting;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AgentPromptCard(
                  title: meta.title,
                  summary: meta.summary,
                  busy: launching,
                  ready: mcp.ready && !busy,
                  highlight: isThis,
                  promptPath: isThis ? mcp.agentPromptPath : null,
                  onStart: () async {
                    final text = await ref
                        .read(mcpProvider.notifier)
                        .startAgentPromptRoutine(meta.id);
                    if (!context.mounted) return;
                    if (text != null) {
                      await _copy(
                        context,
                        text,
                        snack:
                            'Prompt copied — paste into OpenCode or your AI IDE',
                      );
                    }
                  },
                  onCopyOnly: () async {
                    final text = await ref
                        .read(mcpProvider.notifier)
                        .preparePromptOnly(meta.id);
                    if (!context.mounted) return;
                    if (text != null) {
                      await _copy(
                        context,
                        text,
                        snack: 'Prompt copied to clipboard',
                      );
                    }
                  },
                ),
              );
            }),
            if (mcp.agentPromptPath != null) ...[
              Text(
                'Prompt file: ${mcp.agentPromptPath}',
                style: TextStyle(fontSize: 10, color: p.textMuted),
              ),
              const SizedBox(height: 6),
              _CopyTile(
                label: 'Copy last prompt again',
                detail: mcp.lastAgentPromptId?.name ?? 'prompt',
                onCopy: () {
                  final text = mcp.agentPromptText;
                  if (text != null) {
                    _copy(context, text, snack: 'Prompt copied');
                  }
                },
              ),
            ],
          ],

          const SizedBox(height: 20),
          const _Heading('Ways to work'),
          const SizedBox(height: 4),
          Text(
            'Pick one. Each path does a different job.',
            style: TextStyle(fontSize: 11, color: p.textMuted, height: 1.4),
          ),
          const SizedBox(height: 10),
          const _WorkflowPath(
            title: 'Autonomous — Patroller drives',
            body:
                'Patroller runs OpenCode for you. May change the open project.',
          ),
          const _WorkflowPath(
            title: 'Bind MCP — plug tools in',
            body:
                'Section 2. Setup only for DIY agents. No agent run, no pubspec.',
          ),
          const _WorkflowPath(
            title: 'Copy prompt — DIY homework sheet',
            body:
                'Section 3. Get a filled prompt for your own AI. '
                'Patroller does not run it.',
          ),
          const _WorkflowPath(
            title: 'Record tab (optional)',
            body:
                'You drive: interact on a simulator, then export a patrolTest.',
          ),
        ],
      ),
    );
  }

  static String _installLabel(
    McpState mcp, {
    required String packageId,
    required bool installed,
  }) {
    final installingThis = mcp.installing &&
        (mcp.installingPackage == packageId ||
            mcp.installingPackage == 'both' ||
            mcp.installingPackage == 'missing');
    if (installingThis) return 'Installing…';
    return installed ? 'Update' : 'Install';
  }

  static Future<void> _copy(
    BuildContext context,
    String value, {
    String snack = 'Copied to clipboard',
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snack),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

class _AgentPromptCard extends StatelessWidget {
  const _AgentPromptCard({
    required this.title,
    required this.summary,
    required this.busy,
    required this.ready,
    required this.highlight,
    required this.promptPath,
    required this.onStart,
    required this.onCopyOnly,
  });

  final String title;
  final String summary;
  final bool busy;
  final bool ready;
  final bool highlight;
  final String? promptPath;
  final VoidCallback onStart;
  final VoidCallback onCopyOnly;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight
              ? PatrolColors.violet400.withValues(alpha: 0.5)
              : p.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                size: 16,
                color: PatrolColors.violet400,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            summary,
            style: TextStyle(fontSize: 11, color: p.textMuted, height: 1.4),
          ),
          if (promptPath != null) ...[
            const SizedBox(height: 6),
            Text(
              promptPath!,
              style: TextStyle(fontSize: 10, color: p.textFaint),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionChip(
                label: busy ? 'Preparing…' : 'Bind MCP + copy prompt',
                icon: Icons.play_arrow_rounded,
                color: PatrolColors.violet400,
                enabled: ready && !busy,
                onPressed: onStart,
              ),
              _ActionChip(
                label: 'Copy prompt',
                icon: Icons.copy_outlined,
                color: PatrolColors.sky400,
                enabled: !busy,
                onPressed: onCopyOnly,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoutineCard extends StatefulWidget {
  const _RoutineCard({
    required this.state,
    required this.onRefresh,
    required this.onGoalChanged,
    required this.onModelChanged,
    required this.onPubGet,
    required this.onInstallOpenCode,
    required this.onRemoveDependency,
    required this.onToggleDirtyWorktree,
    required this.onRespondPermission,
    required this.onStart,
    required this.onApprove,
    required this.onStop,
  });

  final RoutineState state;
  final VoidCallback onRefresh;
  final ValueChanged<String> onGoalChanged;
  final ValueChanged<String?> onModelChanged;
  final VoidCallback onPubGet;
  final VoidCallback onInstallOpenCode;
  final ValueChanged<String> onRemoveDependency;
  final ValueChanged<bool> onToggleDirtyWorktree;
  final void Function(String requestId, bool allow) onRespondPermission;
  final VoidCallback onStart;
  final VoidCallback onApprove;
  final VoidCallback onStop;

  @override
  State<_RoutineCard> createState() => _RoutineCardState();
}

class _RoutineCardState extends State<_RoutineCard> {
  bool _showChecksDetail = false;

  @override
  Widget build(BuildContext context) {
    final palette = PatrolPalette.of(context);
    final readiness = widget.state.readiness;
    final canStart = widget.state.canStartRoutine;
    final perm = widget.state.pendingPermissionRequest;

    final passedChecks = readiness?.checks.where((c) => c.ok).length ?? 0;
    final totalChecks = readiness?.checks.length ?? 0;
    final failedChecks = totalChecks - passedChecks;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: PatrolColors.violet400.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: PatrolColors.violet400.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: PatrolColors.violet400,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Autonomous — Patroller drives',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Patroller runs OpenCode to explore journeys and repair test flows.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              AccessibleIconButton(
                icon: Icons.refresh_rounded,
                label: 'Refresh routine readiness',
                onPressed: widget.state.busy ? null : widget.onRefresh,
                size: 14,
                color: palette.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Collapsible Readiness Bar (Shadcn Accordion Badge style)
          if (readiness != null) ...[
            InkWell(
              onTap: () => setState(() => _showChecksDetail = !_showChecksDetail),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      failedChecks == 0
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      size: 14,
                      color: failedChecks == 0
                          ? PatrolColors.psPassed
                          : PatrolColors.amber,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      failedChecks == 0
                          ? 'All $totalChecks readiness checks passed'
                          : '$passedChecks of $totalChecks checks passed · $failedChecks warning${failedChecks == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: failedChecks == 0
                            ? PatrolColors.psPassed
                            : PatrolColors.amber,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _showChecksDetail ? 'Hide checks' : 'Details',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: palette.textMuted,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showChecksDetail
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: palette.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (_showChecksDetail) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.surfaceMuted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: palette.border.withValues(alpha: 0.5)),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: readiness.checks.map((check) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: check.ok
                              ? PatrolColors.psPassed.withValues(alpha: 0.3)
                              : PatrolColors.amber.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            check.ok ? Icons.check : Icons.warning_amber_rounded,
                            size: 11,
                            color: check.ok
                                ? PatrolColors.psPassed
                                : PatrolColors.amber,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            check.label,
                            style: TextStyle(
                              fontSize: 10,
                              color: palette.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],

          // Allow dirty Git worktree checkbox
          Row(
            children: [
              SizedBox(
                height: 20,
                width: 20,
                child: Checkbox(
                  value: widget.state.allowDirtyWorktree,
                  onChanged: widget.state.busy
                      ? null
                      : (val) => widget.onToggleDirtyWorktree(val ?? false),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  side: BorderSide(color: palette.border, width: 1.5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Allow dirty Git worktree (proceed with uncommitted changes)',
                  style: TextStyle(fontSize: 11, color: palette.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Routine Goal Input
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ROUTINE GOAL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: palette.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 5),
              TextFormField(
                initialValue: widget.state.goal,
                minLines: 1,
                maxLines: 3,
                onChanged: widget.onGoalChanged,
                style: TextStyle(fontSize: 12, color: palette.text),
                decoration: InputDecoration(
                  hintText: 'What should the agent explore or repair?',
                  hintStyle: TextStyle(fontSize: 12, color: palette.textMuted),
                  filled: true,
                  fillColor: palette.surfaceMuted,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: PatrolColors.violet400, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Verified zero-cost model dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MODEL SELECTION',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: palette.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 5),
              DropdownButtonFormField<String>(
                initialValue: widget.state.models
                        .any((model) => model.id == widget.state.selectedModel)
                    ? widget.state.selectedModel
                    : null,
                items: widget.state.models
                    .map(
                      (model) => DropdownMenuItem<String>(
                        value: model.id,
                        child: Text(
                          model.id,
                          style: TextStyle(fontSize: 12, color: palette.text),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: widget.state.busy ? null : widget.onModelChanged,
                dropdownColor: palette.fill,
                style: TextStyle(fontSize: 12, color: palette.text),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: palette.surfaceMuted,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: palette.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: PatrolColors.violet400, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          if (widget.state.models.isEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'No verified zero-cost models found. Run "opencode auth login" or configure a free provider model.',
              style: TextStyle(
                fontSize: 10,
                color: PatrolColors.amber,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Remove direct dependency & Pub get
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PROJECT DEPENDENCIES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: palette.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: widget.state.dependencies.isEmpty
                          ? null
                          : widget.state.dependencies.first.name,
                      items: widget.state.dependencies
                          .map(
                            (dependency) => DropdownMenuItem<String>(
                              value: dependency.name,
                              child: Text(
                                '${dependency.name}${dependency.isDev ? ' (dev)' : ''}',
                                style: TextStyle(fontSize: 12, color: palette.text),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: widget.state.busy
                          ? null
                          : (value) {
                              if (value != null) widget.onRemoveDependency(value);
                            },
                      dropdownColor: palette.fill,
                      decoration: InputDecoration(
                        hintText: 'Remove direct dependency',
                        hintStyle: TextStyle(fontSize: 12, color: palette.textMuted),
                        filled: true,
                        fillColor: palette.surfaceMuted,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: palette.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: palette.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: widget.state.busy ? null : widget.onPubGet,
                    icon: const Icon(Icons.sync, size: 14),
                    label: const Text('Pub get', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.surfaceMuted,
                      foregroundColor: PatrolColors.sky400,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: palette.border),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Permission Request Dialog
          if (perm != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PatrolColors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: PatrolColors.amber.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security, size: 16, color: PatrolColors.amber),
                      const SizedBox(width: 6),
                      Text(
                        'Permission Request: ${perm.tool}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: PatrolColors.amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    perm.description,
                    style: TextStyle(fontSize: 11, color: palette.text, height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => widget.onRespondPermission(perm.id, true),
                        icon: const Icon(Icons.check, size: 14),
                        label: const Text('Allow', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PatrolColors.psPassed,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => widget.onRespondPermission(perm.id, false),
                        icon: const Icon(Icons.close, size: 14),
                        label: const Text('Deny', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: PatrolColors.ember,
                          side: const BorderSide(color: PatrolColors.ember),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Approval Scope Section
          if (widget.state.status == RoutineStatus.awaitingApproval && readiness != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PatrolColors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: PatrolColors.amber.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Approval required for setup & execution scope',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: PatrolColors.amber,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (readiness.preview.isNotEmpty)
                    Text(
                      'Planned commands: ${readiness.preview.join(' • ')}',
                      style: TextStyle(fontSize: 10, color: palette.textMuted, height: 1.35),
                    ),
                  Text(
                    'Allowed write paths: ${readiness.effectiveWriteLocations.join(', ')}',
                    style: TextStyle(fontSize: 10, color: palette.textMuted, height: 1.35),
                  ),
                  Text(
                    'Scope bounds: Max 90 mins, 15 iterations, stop after 3 no-progress steps',
                    style: TextStyle(fontSize: 10, color: palette.textMuted, height: 1.35),
                  ),
                  if (readiness.selectedDevice != null)
                    Text(
                      'Target device: ${readiness.selectedDevice}',
                      style: TextStyle(fontSize: 10, color: palette.textMuted, height: 1.35),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          Text(
            routineStatusLabel(widget.state.status),
            style: TextStyle(
              fontSize: 11,
              color: widget.state.status == RoutineStatus.needsAttention
                  ? PatrolColors.ember
                  : palette.textMuted,
            ),
          ),
          if (readiness?.checks.any((check) => check.id == 'opencode' && !check.ok) == true) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: widget.state.busy ? null : widget.onInstallOpenCode,
              icon: const Icon(Icons.download_outlined, size: 14),
              label: const Text('Install OpenCode', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: PatrolColors.amber,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
          if (widget.state.error != null) ...[
            const SizedBox(height: 6),
            _Banner(text: widget.state.error!, error: true),
          ],
          if (widget.state.busy || widget.state.events.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.state.events.isEmpty
                  ? 'Detail output streams to LIVE logs.'
                  : 'Latest: [${widget.state.events.last.kind}] ${widget.state.events.last.message}',
              style: TextStyle(fontSize: 10, color: palette.textMuted, height: 1.35),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.state.events.isNotEmpty)
              Text(
                'Full routine output is in LIVE logs.',
                style: TextStyle(fontSize: 10, color: palette.textMuted),
              ),
          ],
          const SizedBox(height: 14),

          // Primary Solid Action Button (Shadcn Style)
          SizedBox(
            height: 38,
            width: double.infinity,
            child: widget.state.status == RoutineStatus.awaitingApproval
                ? ElevatedButton.icon(
                    onPressed: widget.onApprove,
                    icon: const Icon(Icons.verified_user_outlined, size: 16),
                    label: const Text('Approve & Start', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PatrolColors.psPassed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                : widget.state.busy
                    ? ElevatedButton.icon(
                        onPressed: widget.onStop,
                        icon: const Icon(Icons.stop_circle_outlined, size: 16),
                        label: const Text('Stop Routine', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PatrolColors.ember,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: canStart ? widget.onStart : null,
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Start Routine', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PatrolColors.violet400,
                          disabledBackgroundColor: palette.surfaceMuted,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: p.text,
      ),
    );
  }
}

class _MachinePackageCard extends StatelessWidget {
  const _MachinePackageCard({
    required this.req,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.installing,
    required this.enabled,
    required this.onInstall,
  });

  final McpRequirement? req;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final bool installing;
  final bool enabled;
  final VoidCallback? onInstall;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final ok = req?.ok ?? false;
    final detail = req?.detail ?? 'Not checked yet';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: ok
              ? PatrolColors.psPassed.withValues(alpha: 0.35)
              : p.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              ok ? Icons.check_circle : Icons.cloud_download_outlined,
              size: 18,
              color: ok ? PatrolColors.psPassed : PatrolColors.amber,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: p.textMuted, height: 1.35),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 11,
                    color: ok ? PatrolColors.psPassed : p.textMuted,
                  ),
                ),
                if (!ok && req?.fixHint != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      req!.fixHint!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: PatrolColors.amber,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (actionLabel != null && onInstall != null) ...[
            const SizedBox(width: 8),
            _MiniInstallButton(
              label: actionLabel!,
              installing: installing,
              enabled: enabled,
              onPressed: onInstall!,
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniInstallButton extends StatelessWidget {
  const _MiniInstallButton({
    required this.label,
    required this.installing,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool installing;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !installing;
    return Opacity(
      opacity: active ? 1 : 0.45,
      child: Material(
        color: PatrolColors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: active ? onPressed : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: PatrolColors.amber.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (installing)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: PatrolColors.amber,
                    ),
                  )
                else
                  const Icon(
                    Icons.download_outlined,
                    size: 14,
                    color: PatrolColors.amber,
                  ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: PatrolColors.amber,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReqRow extends StatelessWidget {
  const _ReqRow({required this.req});

  final McpRequirement req;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final ok = req.ok;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ok
              ? PatrolColors.psPassed.withValues(alpha: 0.35)
              : PatrolColors.ember.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.error_outline,
            size: 16,
            color: ok ? PatrolColors.psPassed : PatrolColors.ember,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  req.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  req.detail,
                  style: TextStyle(fontSize: 10, color: p.textMuted),
                ),
                if (!ok && req.fixHint != null)
                  Text(
                    req.fixHint!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: PatrolColors.amber,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.error});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? PatrolColors.ember : PatrolColors.psPassed;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color, height: 1.35),
      ),
    );
  }
}

class _WorkflowPath extends StatelessWidget {
  const _WorkflowPath({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: PatrolColors.violet400.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 11,
                    color: p.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyTile extends StatelessWidget {
  const _CopyTile({
    required this.label,
    required this.detail,
    required this.onCopy,
  });

  final String label;
  final String detail;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    return Material(
      color: p.surfaceMuted,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onCopy,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: TextStyle(fontSize: 10, color: p.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.copy, size: 14, color: p.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
