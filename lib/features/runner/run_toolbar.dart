import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/runner_helpers.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/runner_provider.dart';
import '../../widgets/accessible_icon_button.dart';
import '../../widgets/patrol_components.dart';

class RunToolbar extends ConsumerStatefulWidget {
  const RunToolbar({
    super.key,
    required this.onOpenProject,
    required this.onRefreshTests,
    required this.onOpenSettings,
  });

  final VoidCallback onOpenProject;
  final VoidCallback onRefreshTests;
  final VoidCallback onOpenSettings;

  @override
  ConsumerState<RunToolbar> createState() => _RunToolbarState();
}

class _RunToolbarState extends ConsumerState<RunToolbar> {
  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final runner = ref.watch(runnerProvider);
    final project = app.currentProject;
    final selectedFile = app.selectedFile;
    final selectedDevice = runner.selectedDevice;
    final lifecycle = resolveLifecycle(runner.currentRun);
    final sessionBusy = isSessionBusy(runner.isRunning, runner.currentRun);

    final isTestRun = runner.isRunning &&
        runner.currentRun?.runMode.name == 'test' &&
        runner.runAllContext == null;
    final isQueueRun = runner.isRunning && runner.runAllContext != null;
    final isHotRun = runner.isRunning &&
        runner.currentRun?.runMode == RunMode.develop;
    final isHotSuite = runner.isRunning &&
        runner.currentRun?.runMode == RunMode.developSuite;
    final isHotSession = isHotRun || isHotSuite;
    final hotRestartBlock = hotRestartDisabledReason(
      isRunning: runner.isRunning,
      currentRun: runner.currentRun,
    );

    final runDisabled = getRunDisabledReason(
      hasProject: project != null,
      hasSelectedFile: selectedFile != null,
      isRunning: runner.isRunning,
      selectedDevice: selectedDevice,
      currentRun: runner.currentRun,
    );
    final queueDisabled = getQueueRunDisabledReason(
      hasProject: project != null,
      hasTestFiles: app.testFiles.isNotEmpty,
      isRunning: runner.isRunning,
      selectedDevice: selectedDevice,
      currentRun: runner.currentRun,
    );

    final queueStatus = runner.queueStatus;
    final queueProgress = queueStatus != null &&
            queueStatus.status == QueueStatus.running
        ? '${queueStatus.passedCount + queueStatus.failedCount + queueStatus.cancelledCount + queueStatus.skippedCount}/${queueStatus.total} · ${queueStatus.passedCount} passed · ${queueStatus.failedCount} failed · ${queueStatus.skippedCount} skipped'
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      decoration: BoxDecoration(
        color: PatrolColors.mist,
        border: Border(
          bottom: BorderSide(color: PatrolColors.pebble.withValues(alpha: 0.8)),
        ),
        boxShadow: [
          BoxShadow(
            color: PatrolColors.obsidian.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const PatrolBrandMark(size: 30),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                project?.projectName ?? 'Patroller',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: PatrolColors.ink,
                ),
              ),
              Text(
                project != null ? 'Patrol test runner' : 'Open a project to begin',
                style: const TextStyle(fontSize: 9, color: PatrolColors.steel),
              ),
            ],
          ),
          const SizedBox(width: 6),
          AccessibleIconButton(
            icon: Icons.folder_open_rounded,
            label: 'Open project',
            size: 14,
            onPressed: widget.onOpenProject,
          ),
          if (selectedDevice != null) ...[
            _divider(),
            PatrolStatusDot(
              color: sessionBusy ? PatrolColors.ember : PatrolColors.psPassed,
              pulse: sessionBusy,
            ),
            const SizedBox(width: 8),
            PatrolMetaChip(
              label: selectedDevice.name,
              icon: Icons.phone_iphone_rounded,
              accent: sessionBusy,
            ),
          ],
          _divider(),
          _ActionButton(
            label: 'Test',
            icon: Icons.play_arrow_rounded,
            active: isTestRun,
            enabled: runDisabled == null,
            tooltip: runDisabled ?? 'Run the selected test file once.',
            activeColor: PatrolColors.psPassed,
            onPressed: () => ref.read(runnerProvider.notifier).runSelected(),
          ),
          const SizedBox(width: 6),
          _ActionButton(
            label: 'Test All',
            icon: Icons.format_list_numbered_rounded,
            active: isQueueRun,
            enabled: queueDisabled == null,
            tooltip: queueDisabled ??
                'Run selected files, or all files when none are selected.',
            activeColor: PatrolColors.sky400,
            onPressed: () => ref.read(runnerProvider.notifier).runAll(),
          ),
          const SizedBox(width: 6),
          _ActionButton(
            label: 'Develop',
            icon: Icons.science_outlined,
            active: isHotRun,
            enabled: runDisabled == null,
            tooltip: runDisabled ??
                'Start patrol develop for the selected file.',
            activeColor: PatrolColors.violet500,
            onPressed: () => ref.read(runnerProvider.notifier).develop(),
          ),
          const SizedBox(width: 6),
          _ActionButton(
            label: 'Develop All',
            icon: Icons.layers_outlined,
            active: isHotSuite,
            enabled: queueDisabled == null,
            tooltip: queueDisabled ??
                'Start develop for the selected file, or the first runnable file when none is selected.',
            activeColor: PatrolColors.fuchsia500,
            onPressed: () => ref.read(runnerProvider.notifier).developSuite(),
          ),
          const SizedBox(width: 6),
          if (isHotSession)
            _ActionButton(
              label: 'Restart',
              icon: Icons.refresh_rounded,
              active: hotRestartBlock == null,
              enabled: hotRestartBlock == null,
              tooltip: hotRestartBlock ??
                  'Send hot restart (r) to the running develop session.',
              activeColor: PatrolColors.amberBright,
              onPressed: () => ref.read(runnerProvider.notifier).hotRestart(),
            ),
          if (isHotSession) const SizedBox(width: 6),
          _ActionButton(
            label: lifecycle == RunLifecycle.stopping ? 'Stopping...' : 'Stop',
            icon: Icons.stop_rounded,
            active: lifecycle == RunLifecycle.stopping,
            enabled: sessionBusy || runner.stopFailure != null,
            tooltip: sessionBusy
                ? 'Stop the active test or develop session.'
                : 'Nothing is running.',
            activeColor: PatrolColors.red400,
            onPressed: () => ref.read(runnerProvider.notifier).stop(),
          ),
          const Spacer(),
          if (queueProgress != null)
            PatrolMetaChip(
              label: queueProgress,
              icon: Icons.sync,
              color: PatrolColors.sky400,
            ),
          _divider(),
          AccessibleIconButton(
            icon: Icons.settings_outlined,
            label: 'Open settings',
            size: 15,
            onPressed: widget.onOpenSettings,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            PatrolColors.pebble.withValues(alpha: 0),
            PatrolColors.pebble,
            PatrolColors.pebble.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.enabled,
    required this.tooltip,
    required this.activeColor,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool active;
  final bool enabled;
  final String tooltip;
  final Color activeColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bg = active ? activeColor : activeColor.withValues(alpha: 0.12);
    final fg = active ? PatrolColors.obsidian : activeColor;
    final border = active
        ? Colors.transparent
        : activeColor.withValues(alpha: 0.35);

    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label. $tooltip',
      child: Tooltip(
        message: tooltip,
        child: Opacity(
          opacity: enabled ? 1 : 0.38,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(PatrolRadius.chip),
            elevation: active ? 2 : 0,
            shadowColor: activeColor.withValues(alpha: 0.4),
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(PatrolRadius.chip),
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(PatrolRadius.chip),
                  border: Border.all(color: border),
                  boxShadow: active
                      ? PatrolShadows.glow(activeColor, blur: 10)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: fg),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: active && activeColor == PatrolColors.violet500
                            ? PatrolColors.snow
                            : fg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}