import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/runner_helpers.dart';
import '../../providers/app_provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/runner_provider.dart';
import '../../providers/test_run_state_provider.dart';
import '../../widgets/status_badge.dart';

class WorkflowStatusStrip extends ConsumerWidget {
  const WorkflowStatusStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    final runner = ref.watch(runnerProvider);
    final health = ref.watch(healthProvider);
    final activeRunFile = ref.watch(activeRunFileProvider);

    if (app.currentProject == null) return const SizedBox.shrink();

    final selectionBadge =
        describeTestAllQueueBadge(app.selectedFileIds.length);
    final healthLabel = formatHealthStripLabel(health);
    final healthWarn = health.state == HealthCheckState.failed ||
        (health.state == HealthCheckState.current &&
            (health.warningCount ?? 0) > 0) ||
        health.state == HealthCheckState.stale;

    final activeFileLabel = runner.isRunning && activeRunFile != null
        ? activeRunFile.fileName
        : (app.selectedFile?.fileName ?? 'None');
    final activeFileWarn =
        !runner.isRunning && app.selectedFile == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0x6609090B),
        border: Border(bottom: BorderSide(color: PatrolColors.pebble)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            WorkflowStatusBadge(
              label: 'Project',
              value: app.currentProject!.projectName,
            ),
            const SizedBox(width: 8),
            WorkflowStatusBadge(
              label: 'Device',
              value: runner.selectedDevice?.name ?? 'No device',
              warn: runner.selectedDevice == null,
            ),
            const SizedBox(width: 8),
            WorkflowStatusBadge(
              label: runner.isRunning ? 'Running file' : 'Selected file',
              value: activeFileLabel,
              warn: activeFileWarn,
            ),
            const SizedBox(width: 8),
            WorkflowStatusBadge(
              label: selectionBadge.label,
              value: selectionBadge.value,
            ),
            const SizedBox(width: 8),
            WorkflowStatusBadge(
              label: 'Health',
              value: healthLabel,
              warn: healthWarn,
            ),
          ],
        ),
      ),
    );
  }
}