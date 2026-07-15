import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/runner_helpers.dart';
import '../../providers/app_provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/runner_provider.dart';
import '../../providers/simulator_driver_readiness_provider.dart';
import '../../providers/test_run_state_provider.dart';
import '../../widgets/status_badge.dart';

class WorkflowStatusStrip extends ConsumerWidget {
  const WorkflowStatusStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProject = ref.watch(
      appProvider.select((state) => state.currentProject),
    );
    if (currentProject == null) return const SizedBox.shrink();

    final selectedFileIdsLength = ref.watch(
      appProvider.select((state) => state.selectedFileIds.length),
    );
    final selectedFile = ref.watch(
      appProvider.select((state) => state.selectedFile),
    );

    final selectedDevice = ref.watch(
      runnerProvider.select((state) => state.selectedDevice),
    );
    final isRunning = ref.watch(
      runnerProvider.select((state) => state.isRunning),
    );

    final healthState = ref.watch(
      healthProvider.select((state) => state.state),
    );
    final healthWarningCount = ref.watch(
      healthProvider.select((state) => state.warningCount),
    );

    final showRepairAction = ref.watch(
      simulatorDriverReadinessProvider.select(
        (state) => state.showRepairAction,
      ),
    );
    final activeRunFile = ref.watch(activeRunFileProvider);

    final selectionBadge = describeTestAllQueueBadge(selectedFileIdsLength);
    final driverIssue = showRepairAction;
    final healthLabel = healthState == HealthCheckState.current &&
            driverIssue &&
            (healthWarningCount ?? 0) == 0
        ? 'Driver issue'
        : formatHealthStripLabel(healthState, healthWarningCount);
    final healthWarn = healthState == HealthCheckState.failed ||
        driverIssue ||
        (healthState == HealthCheckState.current &&
            (healthWarningCount ?? 0) > 0) ||
        healthState == HealthCheckState.stale;

    final activeFileLabel = isRunning && activeRunFile != null
        ? middleTruncate(activeRunFile.fileName, 36)
        : middleTruncate(selectedFile?.fileName ?? 'None', 36);
    final activeFileWarn = !isRunning && selectedFile == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: PatrolColors.obsidian.withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(color: PatrolColors.pebble.withValues(alpha: 0.6)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            WorkflowStatusBadge(
              label: 'Project',
              value: middleTruncate(currentProject.projectName, 28),
              icon: Icons.folder_outlined,
            ),
            const SizedBox(width: 8),
            WorkflowStatusBadge(
              label: 'Device',
              value: selectedDevice?.name ?? 'No device',
              warn: selectedDevice == null,
              icon: Icons.phone_iphone_outlined,
            ),
            const SizedBox(width: 8),
            WorkflowStatusBadge(
              label: isRunning ? 'Running file' : 'Selected file',
              value: activeFileLabel,
              warn: activeFileWarn,
              icon: Icons.description_outlined,
              accent: PatrolColors.amber,
            ),
            const SizedBox(width: 8),
            WorkflowStatusBadge(
              label: selectionBadge.label,
              value: selectionBadge.value,
              icon: Icons.checklist_rounded,
              accent: PatrolColors.sky400,
            ),
            const SizedBox(width: 8),
            WorkflowStatusBadge(
              label: 'Health',
              value: healthLabel,
              warn: healthWarn,
              icon: Icons.monitor_heart_outlined,
              accent: PatrolColors.orange400,
            ),
          ],
        ),
      ),
    );
  }
}
