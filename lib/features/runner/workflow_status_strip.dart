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
    final app = ref.watch(appProvider);
    final runner = ref.watch(runnerProvider);
    final health = ref.watch(healthProvider);
    final readiness = ref.watch(simulatorDriverReadinessProvider);
    final activeRunFile = ref.watch(activeRunFileProvider);

    if (app.currentProject == null) return const SizedBox.shrink();

    final selectionBadge =
        describeTestAllQueueBadge(app.selectedFileIds.length);
    final driverIssue = readiness.showRepairAction;
    final healthLabel = health.state == HealthCheckState.current &&
            driverIssue &&
            (health.warningCount ?? 0) == 0
        ? 'Driver issue'
        : formatHealthStripLabel(health);
    final healthWarn = health.state == HealthCheckState.failed ||
        driverIssue ||
        (health.state == HealthCheckState.current &&
            (health.warningCount ?? 0) > 0) ||
        health.state == HealthCheckState.stale;

    final activeFileLabel = runner.isRunning && activeRunFile != null
        ? middleTruncate(activeRunFile.fileName, 36)
        : middleTruncate(app.selectedFile?.fileName ?? 'None', 36);
    final activeFileWarn = !runner.isRunning && app.selectedFile == null;

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
              value: middleTruncate(app.currentProject!.projectName, 28),
              icon: Icons.folder_outlined,
            ),
            const SizedBox(width: 8),
            WorkflowStatusBadge(
              label: 'Device',
              value: runner.selectedDevice?.name ?? 'No device',
              warn: runner.selectedDevice == null,
              icon: Icons.phone_iphone_outlined,
            ),
            const SizedBox(width: 8),
            WorkflowStatusBadge(
              label: runner.isRunning ? 'Running file' : 'Selected file',
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