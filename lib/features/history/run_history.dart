import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../models/models.dart';
import '../../domain/runner_helpers.dart';
import '../../domain/simulator_driver_readiness.dart' show historyFilterLabel;
import '../../providers/app_provider.dart';
import '../../providers/facade_provider.dart';
import '../../providers/runner_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/accessible_icon_button.dart';
import '../../widgets/patrol_components.dart';
import '../../widgets/status_badge.dart';

class RunHistory extends ConsumerStatefulWidget {
  const RunHistory({super.key});

  @override
  ConsumerState<RunHistory> createState() => _RunHistoryState();
}

class _RunHistoryState extends ConsumerState<RunHistory> {
  List<RunRecord> _records = [];
  String? _selectedRunId;
  String _filter = 'all';
  String _search = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadHistory);
  }

  Future<void> _loadHistory() async {
    final project = ref.read(appProvider).currentProject;
    if (project == null) return;
    setState(() => _loading = true);
    try {
      final records = await ref
          .read(patrolStudioFacadeProvider)
          .history
          .getAll(project.projectPath);
      setState(() => _records = records);
    } catch (e) {
      ref.read(runnerProvider.notifier).showSnackbar(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  List<RunRecord> get _filtered {
    return _records.where((record) {
      if (_filter == 'failed' &&
          record.status != RunRecordStatus.failed &&
          record.status != RunRecordStatus.error) {
        return false;
      }
      if (_filter == 'passed' && record.status != RunRecordStatus.passed) {
        return false;
      }
      if (_filter == 'cancelled' &&
          record.status != RunRecordStatus.cancelled) {
        return false;
      }
      if (_filter == 'batches' && record.isQueueSummary != true) return false;
      if (_search.trim().isNotEmpty) {
        final q = _search.toLowerCase();
        final file = record.targetFile?.split('/').last.toLowerCase() ?? '';
        if (!file.contains(q) &&
            !record.fullCommandForDisplay.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    if (_loading && _records.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final filtered = _filtered;
    final selected = _selectedRunId == null
        ? null
        : _records.where((r) => r.runId == _selectedRunId).firstOrNull;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: p.border)),
          ),
          child: Row(
            children: [
              Text(
                'RUN HISTORY',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const Spacer(),
              AccessibleIconButton(
                icon: Icons.refresh,
                label: 'Refresh run history',
                onPressed: _loadHistory,
                size: 12,
              ),
              if (_records.isNotEmpty) ...[
                const SizedBox(width: 4),
                AccessibleIconButton(
                  icon: Icons.delete_sweep_outlined,
                  label: 'Clear all history',
                  onPressed: _clearAll,
                  size: 12,
                  color: p.textMuted,
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(
              hintText: 'Search runs...',
              prefixIcon: Icon(Icons.search, size: 14),
              isDense: true,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: ['all', 'failed', 'passed', 'cancelled', 'batches']
                .map((chip) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: PatrolFilterPill(
                  label: historyFilterLabel(chip),
                  selected: _filter == chip,
                  color: switch (chip) {
                    'all' => p.textMuted,
                    'failed' => PatrolColors.psFailed,
                    'passed' => PatrolColors.psPassed,
                    'cancelled' => PatrolColors.orange400,
                    'batches' => PatrolColors.violet400,
                    _ => null,
                  },
                  onTap: () => setState(() => _filter = chip),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No runs yet',
                    style: TextStyle(fontSize: 12, color: p.textMuted),
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final record = filtered[index];
                    final isSelected = _selectedRunId == record.runId;
                    return InkWell(
                      onTap: () =>
                          setState(() => _selectedRunId = record.runId),
                      child: Container(
                        color: isSelected
                            ? p.surfaceMuted
                            : Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            StatusBadge(status: record.status.name),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    middleTruncate(
                                      _historyTitle(record),
                                      42,
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: p.text,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${record.status.name} · ${record.runMode.toJson()} · ${record.durationMs != null ? '${(record.durationMs! / 1000).toStringAsFixed(1)}s' : '-'}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: p.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AccessibleIconButton(
                              icon: Icons.delete_outline,
                              label: 'Delete run record',
                              onPressed: () => _deleteRun(record),
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (selected != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: p.border)),
              color: p.surfaceMuted,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected.fullCommandForDisplay,
                  style: TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 10,
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: selected.fullCommandForDisplay),
                        );
                        ref
                            .read(runnerProvider.notifier)
                            .showSnackbar('Command copied');
                      },
                      icon: const Icon(Icons.copy, size: 12),
                      label: const Text('Copy command'),
                    ),
                    if (isFailedRunStatus(selected.status)) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () {
                          final text = formatRunLogsForExport(
                            logs: selected.logs,
                            combinedLog: selected.combinedLog,
                            stderrLog: selected.stderrLog,
                          );
                          if (text.trim().isEmpty) {
                            ref.read(runnerProvider.notifier).showSnackbar(
                                  'No logs saved for this run',
                                );
                            return;
                          }
                          Clipboard.setData(ClipboardData(text: text));
                          ref
                              .read(runnerProvider.notifier)
                              .showSnackbar('Failed logs copied');
                        },
                        icon: const Icon(Icons.content_paste, size: 12),
                        label: const Text('Copy failed logs'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _historyTitle(RunRecord record) {
    final file = record.targetFile?.split('/').last;
    if (file != null) return file;
    final label = record.queueLabel;
    if (label != null) {
      return label.replaceFirst(RegExp(r'^Queue\b'), 'Batch');
    }
    return 'Run';
  }

  Future<void> _deleteRun(RunRecord record) async {
    final project = ref.read(appProvider).currentProject;
    if (project == null) return;
    final settings = ref.read(settingsProvider).settings;
    if (settings.confirmBeforeClearHistory) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete run record?'),
          content: Text(
            'Remove this ${record.runMode.toJson()} run from history? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await ref.read(patrolStudioFacadeProvider).history.delete(
            record.runId,
            project.projectPath,
          );
      setState(() {
        _records.removeWhere((r) => r.runId == record.runId);
        if (_selectedRunId == record.runId) _selectedRunId = null;
      });
    } catch (e) {
      ref.read(runnerProvider.notifier).showSnackbar(e.toString());
    }
  }

  Future<void> _clearAll() async {
    final project = ref.read(appProvider).currentProject;
    if (project == null) return;
    final settings = ref.read(settingsProvider).settings;
    if (settings.confirmBeforeClearHistory) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear all history?'),
          content: const Text(
            'Remove all run records for this project? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await ref.read(patrolStudioFacadeProvider).history.clear(project.projectPath);
      setState(() {
        _records.clear();
        _selectedRunId = null;
      });
    } catch (e) {
      ref.read(runnerProvider.notifier).showSnackbar(e.toString());
    }
  }
}