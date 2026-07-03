import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/facade_provider.dart';
import '../../providers/runner_provider.dart';

class EnvironmentHealth extends ConsumerStatefulWidget {
  const EnvironmentHealth({super.key});

  @override
  ConsumerState<EnvironmentHealth> createState() =>
      _EnvironmentHealthState();
}

class _EnvironmentHealthState extends ConsumerState<EnvironmentHealth> {
  List<HealthCheck> _checks = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _runChecks());
  }

  Future<void> _runChecks({bool forceRefresh = false}) async {
    final project = ref.read(appProvider).currentProject;
    if (project == null) return;
    setState(() => _loading = true);
    try {
      final results = await ref
          .read(patrolStudioFacadeProvider)
          .health
          .check(project.projectPath, forceRefresh: forceRefresh);
      final warnings = results
          .where(
            (c) =>
                c.status == HealthStatus.warning ||
                c.status == HealthStatus.failed,
          )
          .length;
      ref.read(appProvider.notifier).setHealthWarningCount(warnings);
      ref.read(appProvider.notifier).setHealthStale(false);
      setState(() => _checks = results);
    } catch (e) {
      ref.read(runnerProvider.notifier).showSnackbar(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final passed =
        _checks.where((c) => c.status == HealthStatus.passed).length;
    final warnings =
        _checks.where((c) => c.status == HealthStatus.warning).length;
    final failed =
        _checks.where((c) => c.status == HealthStatus.failed).length;

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
              const Spacer(),
              if (_loading)
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
                onPressed: _checks.isEmpty
                    ? null
                    : () {
                        final text = _checks
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
        if (_checks.isNotEmpty)
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
          child: _checks.isEmpty
              ? const Center(
                  child: Text(
                    'Run health checks to verify your environment.',
                    style: TextStyle(fontSize: 12, color: PatrolColors.steel),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _checks.length,
                  itemBuilder: (context, index) {
                    final check = _checks[index];
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
                ),
        ),
      ],
    );
  }
}