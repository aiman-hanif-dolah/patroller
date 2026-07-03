import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/runner_helpers.dart';
import '../../providers/app_provider.dart';
import '../../providers/runner_provider.dart';
import '../../widgets/status_badge.dart';

class WorkflowStatusStrip extends ConsumerWidget {
  const WorkflowStatusStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    final runner = ref.watch(runnerProvider);

    if (app.currentProject == null) return const SizedBox.shrink();

    final queueBadge =
        describeTestAllQueueBadge(app.selectedFileIds.length);
    final healthWarnings = app.healthWarningCount;
    final healthLabel = healthWarnings == null
        ? '—'
        : healthWarnings == 0
            ? '0 warnings'
            : '$healthWarnings warning${healthWarnings == 1 ? '' : 's'}';

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
              label: 'Active file',
              value: app.selectedFile?.fileName ?? 'None',
              warn: app.selectedFile == null,
            ),
            const SizedBox(width: 8),
            WorkflowStatusBadge(
              label: queueBadge.label,
              value: queueBadge.value,
            ),
            const SizedBox(width: 8),
            WorkflowStatusBadge(
              label: 'Health',
              value: healthLabel,
              warn: healthWarnings != null && healthWarnings > 0,
            ),
          ],
        ),
      ),
    );
  }
}