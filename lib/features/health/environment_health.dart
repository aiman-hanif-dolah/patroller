import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/runner_provider.dart';

class EnvironmentHealth extends ConsumerStatefulWidget {
  const EnvironmentHealth({super.key});

  @override
  ConsumerState<EnvironmentHealth> createState() =>
      _EnvironmentHealthState();
}

class _EnvironmentHealthState extends ConsumerState<EnvironmentHealth> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_runChecks);
  }

  Future<void> _runChecks({bool forceRefresh = false}) async {
    final project = ref.read(appProvider).currentProject;
    if (project == null) return;
    await ref
        .read(healthProvider.notifier)
        .runChecks(project.projectPath, forceRefresh: forceRefresh);
    final health = ref.read(healthProvider);
    ref.read(appProvider.notifier).setHealthWarningCount(health.warningCount);
    ref.read(appProvider.notifier).setHealthStale(
          health.state == HealthCheckState.stale,
        );
  }

  @override
  Widget build(BuildContext context) {
    final health = ref.watch(healthProvider);
    final checks = health.checks;
    final passed =
        checks.where((c) => c.status == HealthStatus.passed).length;
    final warnings =
        checks.where((c) => c.status == HealthStatus.warning).length;
    final failed =
        checks.where((c) => c.status == HealthStatus.failed).length;
    final loading = health.state == HealthCheckState.checking;

    ref.listen(appProvider.select((s) => s.healthStale), (prev, next) {
      if (next == true && health.state == HealthCheckState.current) {
        ref.read(healthProvider.notifier).markStale();
      }
    });

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: PatrolColors.pebble)),
          ),
          child: Row(
            children: [
              Text(
                'ENVIRONMENT HEALTH',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(width: 8),
              Text(
                _stateLabel(health.state),
                style: TextStyle(
                  fontSize: 10,
                  color: _stateColor(health.state),
                ),
              ),
              const Spacer(),
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  onPressed: () => _runChecks(forceRefresh: true),
                  icon: const Icon(Icons.refresh, size: 14),
                  tooltip: 'Re-run checks',
                ),
              IconButton(
                onPressed: checks.isEmpty
                    ? null
                    : () {
                        final text = checks
                            .map(
                              (c) =>
                                  '${c.name}: ${c.status.name}\n${c.explanation}\n${c.fixInstruction}',
                            )
                            .join('\n\n');
                        Clipboard.setData(ClipboardData(text: text));
                        ref
                            .read(runnerProvider.notifier)
                            .showSnackbar('Diagnostics copied');
                      },
                icon: const Icon(Icons.copy, size: 14),
                tooltip: 'Copy diagnostics',
              ),
            ],
          ),
        ),
        if (checks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(
                  '$passed passed',
                  style: const TextStyle(
                    fontSize: 10,
                    color: PatrolColors.psPassed,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$warnings warnings',
                  style: const TextStyle(
                    fontSize: 10,
                    color: PatrolColors.ember,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$failed failed',
                  style: const TextStyle(
                    fontSize: 10,
                    color: PatrolColors.red400,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _buildBody(health),
        ),
      ],
    );
  }

  Widget _buildBody(HealthState health) {
    if (health.state == HealthCheckState.unchecked) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Health has not been checked yet.',
                style: TextStyle(fontSize: 12, color: PatrolColors.steel),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _runChecks,
                child: const Text('Run checks'),
              ),
            ],
          ),
        ),
      );
    }

    if (health.state == HealthCheckState.checking && health.checks.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (health.checks.isEmpty) {
      return Center(
        child: Text(
          health.error ?? 'No health results available.',
          style: const TextStyle(fontSize: 12, color: PatrolColors.red400),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: health.checks.length,
      itemBuilder: (context, index) {
        final check = health.checks[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PatrolColors.fog,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PatrolColors.pebble),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                check.status == HealthStatus.passed
                    ? Icons.check_circle_outline
                    : check.status == HealthStatus.warning
                        ? Icons.warning_amber_outlined
                        : Icons.cancel_outlined,
                size: 14,
                color: check.status == HealthStatus.passed
                    ? PatrolColors.psPassed
                    : check.status == HealthStatus.warning
                        ? PatrolColors.ember
                        : PatrolColors.red400,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      check.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PatrolColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      check.explanation,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PatrolColors.graphite,
                      ),
                    ),
                    if (check.fixInstruction.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        check.fixInstruction,
                        style: const TextStyle(
                          fontSize: 10,
                          color: PatrolColors.steel,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _stateLabel(HealthCheckState state) {
    return switch (state) {
      HealthCheckState.unchecked => 'Not checked',
      HealthCheckState.checking => 'Checking',
      HealthCheckState.current => 'Current',
      HealthCheckState.stale => 'Stale',
      HealthCheckState.failed => 'Failed',
    };
  }

  Color _stateColor(HealthCheckState state) {
    return switch (state) {
      HealthCheckState.current => PatrolColors.psPassed,
      HealthCheckState.checking => PatrolColors.sky400,
      HealthCheckState.stale => PatrolColors.ember,
      HealthCheckState.failed => PatrolColors.red400,
      HealthCheckState.unchecked => PatrolColors.steel,
    };
  }
}