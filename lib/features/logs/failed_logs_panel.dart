import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/runner_helpers.dart';
import '../../providers/failed_logs_provider.dart';
import '../../providers/runner_provider.dart';
import '../../widgets/accessible_icon_button.dart';
import '../../widgets/status_badge.dart';

class FailedLogsPanel extends ConsumerStatefulWidget {
  const FailedLogsPanel({super.key});

  @override
  ConsumerState<FailedLogsPanel> createState() => _FailedLogsPanelState();
}

class _FailedLogsPanelState extends ConsumerState<FailedLogsPanel> {
  String? _selectedRunId;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final state = ref.watch(failedLogsProvider);
    final entries = state.entries;
    final selected = _selectedRunId == null
        ? null
        : entries.where((e) => e.runId == _selectedRunId).firstOrNull;

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Failed test logs appear here after a run fails.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: p.textMuted),
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: p.border)),
          ),
          child: Row(
            children: [
              Text(
                '${entries.length} FAILED RUN${entries.length == 1 ? '' : 'S'}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  ref.read(failedLogsProvider.notifier).clear();
                  setState(() => _selectedRunId = null);
                },
                child: const Text('Clear all'),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final isSelected = _selectedRunId == entry.runId;
              final title = entry.targetFile?.split('/').last ?? entry.runId;

              return InkWell(
                onTap: () => setState(() => _selectedRunId = entry.runId),
                child: Container(
                  color: isSelected ? p.surfaceMuted : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      StatusBadge(status: entry.status.name),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              middleTruncate(title, 42),
                              style: TextStyle(
                                fontSize: 13,
                                color: p.text,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              entry.startTime,
                              style: TextStyle(
                                fontSize: 10,
                                color: p.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AccessibleIconButton(
                        icon: Icons.copy,
                        label: 'Copy failed logs',
                        onPressed: () => _copyLogs(entry.exportText),
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
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: p.border)),
                color: p.surfaceMuted,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            middleTruncate(
                              selected.targetFile?.split('/').last ??
                                  selected.runId,
                              48,
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: p.text,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _copyLogs(selected.exportText),
                          icon: const Icon(Icons.copy, size: 12),
                          label: const Text('Copy failed logs'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        selected.exportText,
                        style: TextStyle(
                          fontFamily: 'Menlo',
                          fontSize: 10,
                          height: 1.45,
                          color: p.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _copyLogs(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ref.read(runnerProvider.notifier).showSnackbar('Failed logs copied');
  }
}