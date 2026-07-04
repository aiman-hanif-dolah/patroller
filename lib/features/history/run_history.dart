import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/facade_provider.dart';
import '../../providers/runner_provider.dart';
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
      if (_filter == 'queues' && record.isQueueSummary != true) return false;
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
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: PatrolColors.pebble)),
          ),
          child: Row(
            children: [
              Text(
                'RUN HISTORY',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh, size: 12),
                tooltip: 'Refresh history',
              ),
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
            children: ['all', 'failed', 'passed', 'cancelled', 'queues']
                .map((chip) {
              final selectedChip = _filter == chip;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(chip, style: const TextStyle(fontSize: 10)),
                  selected: selectedChip,
                  onSelected: (_) => setState(() => _filter = chip),
                  backgroundColor: PatrolColors.fog,
                  selectedColor: PatrolColors.ink,
                  labelStyle: TextStyle(
                    color: selectedChip
                        ? PatrolColors.obsidian
                        : PatrolColors.steel,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'No runs yet',
                    style: TextStyle(fontSize: 12, color: PatrolColors.steel),
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
                            ? PatrolColors.fog
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
                                    record.targetFile?.split('/').last ??
                                        record.queueLabel ??
                                        'Run',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: PatrolColors.ink,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${record.status.name} · ${record.runMode.toJson()} · ${record.durationMs != null ? '${(record.durationMs! / 1000).toStringAsFixed(1)}s' : '—'}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: PatrolColors.steel,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _deleteRun(record),
                              icon: const Icon(Icons.delete_outline, size: 14),
                              tooltip: 'Delete run',
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
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: PatrolColors.pebble)),
              color: PatrolColors.fog,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected.fullCommandForDisplay,
                  style: const TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 10,
                    color: PatrolColors.graphite,
                  ),
                ),
                const SizedBox(height: 8),
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
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _deleteRun(RunRecord record) async {
    final project = ref.read(appProvider).currentProject;
    if (project == null) return;
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
}