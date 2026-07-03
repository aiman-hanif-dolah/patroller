import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/runner_helpers.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/runner_provider.dart';
import '../../widgets/status_badge.dart';
import '../devices/device_picker.dart';

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
  bool _showDevicePicker = false;

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
      padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
      decoration: const BoxDecoration(
        color: PatrolColors.mist,
        border: Border(bottom: BorderSide(color: PatrolColors.pebble)),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: widget.onOpenProject,
            icon: const Icon(Icons.folder_open, size: 14),
            label: Text(
              project?.projectName ?? 'Patrol Studio',
              overflow: TextOverflow.ellipsis,
            ),
            style: TextButton.styleFrom(
              foregroundColor: PatrolColors.ink,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          _divider(),
          Stack(
            clipBehavior: Clip.none,
            children: [
              TextButton.icon(
                onPressed: () =>
                    setState(() => _showDevicePicker = !_showDevicePicker),
                icon: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: sessionBusy
                        ? PatrolColors.ember
                        : PatrolColors.psPassed,
                    shape: BoxShape.circle,
                  ),
                ),
                label: Text(
                  selectedDevice?.name ?? 'No device',
                  overflow: TextOverflow.ellipsis,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: PatrolColors.ink,
                ),
              ),
              if (_showDevicePicker)
                Positioned(
                  top: 40,
                  left: 0,
                  child: DevicePickerMenu(
                    onClose: () => setState(() => _showDevicePicker = false),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: () =>
                ref.read(runnerProvider.notifier).refreshDevices(),
            icon: const Icon(Icons.refresh, size: 14),
            tooltip: 'Refresh devices',
          ),
          if (selectedDevice != null &&
              selectedDevice.state == DeviceState.shutdown)
            IconButton(
              onPressed: () =>
                  ref.read(runnerProvider.notifier).bootSimulator(),
              icon: const Icon(Icons.power_settings_new, size: 14),
              tooltip: 'Boot simulator',
            ),
          if (selectedDevice != null &&
              selectedDevice.state == DeviceState.booted &&
              !sessionBusy)
            IconButton(
              onPressed: () =>
                  ref.read(runnerProvider.notifier).shutdownSimulator(),
              icon: const Icon(Icons.power_off, size: 14),
              tooltip: 'Shut down simulator',
            ),
          _divider(),
          _ActionButton(
            label: 'Test',
            icon: Icons.play_arrow,
            active: isTestRun,
            enabled: runDisabled == null,
            tooltip: runDisabled ?? 'Run the selected test file once.',
            activeColor: PatrolColors.psPassed,
            onPressed: () => ref.read(runnerProvider.notifier).runSelected(),
          ),
          const SizedBox(width: 6),
          _ActionButton(
            label: 'Test All',
            icon: Icons.format_list_numbered,
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
            tooltip: queueDisabled ?? 'Start develop session for all files.',
            activeColor: PatrolColors.fuchsia500,
            onPressed: () =>
                ref.read(runnerProvider.notifier).developSuite(),
          ),
          const SizedBox(width: 6),
          _ActionButton(
            label: lifecycle == RunLifecycle.stopping ? 'Stopping...' : 'Stop',
            icon: Icons.stop,
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
            Text(
              queueProgress,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: PatrolColors.sky400,
              ),
            ),
          if (runner.currentRun != null) ...[
            const SizedBox(width: 12),
            StatusBadge(
              status: lifecycle?.name ?? runner.currentRun!.status.name,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _activeRunLabel(runner),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: PatrolColors.ink),
              ),
            ),
          ],
          _divider(),
          IconButton(
            onPressed: widget.onOpenSettings,
            icon: const Icon(Icons.settings, size: 15),
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: PatrolColors.pebble,
    );
  }

  String _activeRunLabel(RunnerState runner) {
    final run = runner.currentRun!;
    final target = run.targetFile?.split('/').last ?? 'session';
    if (runner.runAllContext != null) {
      return 'Test All · $target (${runner.runAllContext!.current}/${runner.runAllContext!.total})';
    }
    return '${run.runMode.name} · $target';
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
    final bg = active
        ? activeColor
        : activeColor.withValues(alpha: 0.15);
    final fg = active ? PatrolColors.obsidian : activeColor;
    final border = active
        ? Colors.transparent
        : activeColor.withValues(alpha: 0.4);

    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: fg),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
    );
  }
}