import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/agent_prompts.dart';
import '../../providers/app_provider.dart';
import '../../providers/mcp_provider.dart';
import '../../services/mcp_service.dart';

/// Agent workbench:
/// 1. Install / update Patrol MCP + Marionette MCP **on this machine**
///    (global `dart pub global activate` — never into the Flutter project).
/// 2. Bind those servers to the **currently open project** via Cursor MCP config.
class AgentWorkbenchPanel extends ConsumerStatefulWidget {
  const AgentWorkbenchPanel({super.key});

  @override
  ConsumerState<AgentWorkbenchPanel> createState() =>
      _AgentWorkbenchPanelState();
}

class _AgentWorkbenchPanelState extends ConsumerState<AgentWorkbenchPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mcpProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final project = ref.watch(appProvider).currentProject;
    final mcp = ref.watch(mcpProvider);
    final busy = mcp.installing || mcp.starting || mcp.checking;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Heading('Agent workbench'),
          const SizedBox(height: 6),
          Text(
            'Patroller installs MCP servers on this Mac (not inside your app '
            'project). Once installed, bind them to the open project so Cursor '
            'agents can run Patrol / Marionette against that codebase.',
            style: TextStyle(fontSize: 12, color: p.textMuted, height: 1.45),
          ),
          const SizedBox(height: 16),

          // ── Machine-level install ──────────────────────────────────────
          Row(
            children: [
              const _Heading('1. Install on this machine'),
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
            'Uses dart pub global activate — same as installing from a terminal. '
            'Packages live in your pub cache, shared by all projects.',
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
          const _Heading('2. Bind to open project'),
          const SizedBox(height: 4),
          Text(
            'Writes a Patrol wrapper + merges ~/.cursor/mcp.json so agents use '
            'the machine-installed MCP servers against this project. Does not '
            'add packages to the project pubspec.',
            style: TextStyle(fontSize: 11, color: p.textMuted, height: 1.4),
          ),
          const SizedBox(height: 10),

          if (project == null)
            _Banner(
              text:
                  'Open a Flutter project in Patroller to configure MCP for it. '
                  'You can still install MCP packages above without a project.',
              error: false,
            )
          else ...[
            ...mcp.requirements
                .where((r) =>
                    r.id == 'project' ||
                    r.id == 'pubspec' ||
                    r.id == 'cursor_dir')
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
                  label: mcp.starting ? 'Starting…' : 'Start MCP routine',
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
              detail: '~/.cursor/mcp.json (Patrol + Marionette)',
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
            const _Heading('3. Agent prompt routines'),
            const SizedBox(height: 4),
            Text(
              'Patroller fills a Cursor agent prompt from the open project + '
              'selected simulator, binds MCP, writes the prompt under '
              '~/.cursor/patroller-prompts/, and copies it for paste into '
              'Cursor. Patroller does not run the agent itself — Cursor + MCP do.',
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
                            'Agent prompt copied — paste into Cursor agent chat',
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
                        snack: 'Agent prompt copied to clipboard',
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
                label: 'Copy last agent prompt again',
                detail: mcp.lastAgentPromptId?.name ?? 'prompt',
                onCopy: () {
                  final text = mcp.agentPromptText;
                  if (text != null) {
                    _copy(context, text, snack: 'Agent prompt copied');
                  }
                },
              ),
            ],
          ],

          const SizedBox(height: 20),
          const _Heading('Workflow'),
          const SizedBox(height: 8),
          const _WorkflowStep(
            number: 1,
            title: 'Install MCP on this Mac (above)',
            body:
                'Patroller activates patrol_mcp + marionette_mcp globally once. '
                'No project pubspec changes.',
          ),
          const _WorkflowStep(
            number: 2,
            title: 'Record (Record tab)',
            body:
                'Boot a simulator, click Record, interact in Simulator.app. '
                'Save and export a generated patrolTest.',
          ),
          const _WorkflowStep(
            number: 3,
            title: 'Discover (Patrol MCP)',
            body:
                'During patrol develop, agent calls native-tree and screenshot '
                'to see device state on the open project.',
          ),
          const _WorkflowStep(
            number: 4,
            title: 'Discover (Marionette MCP — optional)',
            body:
                'For Flutter widget keys/text, use Marionette MCP on a debug app '
                'with marionette_flutter.',
          ),
          const _WorkflowStep(
            number: 5,
            title: 'Write & verify (Patrol MCP)',
            body:
                'Agent runs patrol develop via run, adds steps incrementally, '
                'and validates before saving patrol_test/*.dart files.',
          ),
          const _WorkflowStep(
            number: 6,
            title: 'Marionette coverage routine (section 3)',
            body:
                'Start the prompt routine → paste into Cursor → agent explores '
                'with Marionette MCP and writes Patrol tests for gaps only.',
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
                label: busy ? 'Starting…' : 'Start routine + copy prompt',
                icon: Icons.play_arrow_rounded,
                color: PatrolColors.violet400,
                enabled: ready && !busy,
                onPressed: onStart,
              ),
              _ActionChip(
                label: 'Copy prompt only',
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

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep({
    required this.number,
    required this.title,
    required this.body,
  });

  final int number;
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
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.border,
              borderRadius: const BorderRadius.all(Radius.circular(6)),
            ),
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: p.text,
              ),
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
