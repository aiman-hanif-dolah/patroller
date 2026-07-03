import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/log_classification.dart';
import '../../domain/log_sanitizer.dart';
import '../../domain/runner_helpers.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/log_provider.dart';
import '../../providers/runner_provider.dart';


class LogsPanel extends ConsumerStatefulWidget {
  const LogsPanel({super.key, this.searchFocusNode});

  final FocusNode? searchFocusNode;

  @override
  ConsumerState<LogsPanel> createState() => _LogsPanelState();
}

class _LogsPanelState extends ConsumerState<LogsPanel> {
  final _scrollController = ScrollController();
  bool _showJumpToBottom = false;
  bool _showFilterMenu = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logState = ref.watch(logProvider);
    final filteredLogs = ref.watch(filteredLogsProvider);
    final runner = ref.watch(runnerProvider);
    final sessionBusy = isSessionBusy(runner.isRunning, runner.currentRun);

    ref.listen(logProvider.select((s) => s.revision), (prev, next) {
      if (logState.autoScroll && !_showJumpToBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    });

    return Column(
      children: [
        _LogsToolbar(
          searchFocusNode: widget.searchFocusNode,
          showFilterMenu: _showFilterMenu,
          onToggleFilterMenu: () =>
              setState(() => _showFilterMenu = !_showFilterMenu),
          onCloseFilterMenu: () => setState(() => _showFilterMenu = false),
        ),
        Expanded(
          child: Stack(
            children: [
              if (filteredLogs.isEmpty)
                _EmptyLogsState(sessionBusy: sessionBusy)
              else
                Scrollbar(
                  controller: _scrollController,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: _LogLine(log: filteredLogs[index]),
                      );
                    },
                  ),
                ),
              if (_showJumpToBottom)
                Positioned(
                  right: 20,
                  bottom: 12,
                  child: FilledButton.icon(
                    onPressed: () {
                      _scrollController.jumpTo(
                        _scrollController.position.maxScrollExtent,
                      );
                      setState(() => _showJumpToBottom = false);
                    },
                    icon: const Icon(Icons.arrow_downward, size: 12),
                    label: const Text('Jump to bottom'),
                    style: FilledButton.styleFrom(
                      backgroundColor: PatrolColors.ink,
                      foregroundColor: PatrolColors.obsidian,
                      textStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.log});

  final LogEvent log;

  @override
  Widget build(BuildContext context) {
    final category = classifyLog(log);
    final style = logCategoryStyles[category]!;
    final timestamp = formatLogTimestamp(log.timestamp);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontFamily: 'Menlo',
            fontSize: 11,
            height: 1.5,
          ),
          children: [
            TextSpan(
              text: '$timestamp ',
              style: const TextStyle(color: PatrolColors.steel),
            ),
            TextSpan(
              text: '${style.label} ',
              style: TextStyle(
                color: style.tag,
                fontWeight: FontWeight.w600,
              ),
            ),
            ...buildLogTextSpans(
              log.text,
              defaultColor: style.text,
              baseStyle: const TextStyle(
                fontFamily: 'Menlo',
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _LogsToolbar extends ConsumerWidget {
  const _LogsToolbar({
    this.searchFocusNode,
    required this.showFilterMenu,
    required this.onToggleFilterMenu,
    required this.onCloseFilterMenu,
  });

  final FocusNode? searchFocusNode;
  final bool showFilterMenu;
  final VoidCallback onToggleFilterMenu;
  final VoidCallback onCloseFilterMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logState = ref.watch(logProvider);
    final filtered = ref.watch(filteredLogsProvider);
    final filtersActive = isLogFilterActive(logState.logFilters) ||
        logState.logSearch.trim().isNotEmpty;
    final lineLabel = formatLogLineCount(
      logState.logs.length,
      filtered.length,
      filtersActive,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PatrolColors.pebble)),
      ),
      child: Row(
        children: [
          Text(
            'LOGS',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 180,
            child: TextField(
              focusNode: searchFocusNode,
              onChanged: ref.read(logProvider.notifier).setLogSearch,
              style: const TextStyle(fontSize: 10),
              decoration: const InputDecoration(
                hintText: 'Search logs...',
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 12),
                prefixIconConstraints: BoxConstraints(minWidth: 32),
              ),
            ),
          ),
          IconButton(
            onPressed: () => ref
                .read(logProvider.notifier)
                .setAutoScroll(!logState.autoScroll),
            icon: Icon(
              logState.autoScroll ? Icons.pause : Icons.play_arrow,
              size: 12,
            ),
            tooltip: logState.autoScroll
                ? 'Pause auto-scroll'
                : 'Resume auto-scroll',
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onToggleFilterMenu,
                icon: Icon(
                  Icons.filter_list,
                  size: 12,
                  color: filtersActive
                      ? PatrolColors.ink
                      : PatrolColors.steel,
                ),
              ),
              if (showFilterMenu)
                Positioned(
                  top: 36,
                  right: 0,
                  child: _FilterMenu(onClose: onCloseFilterMenu),
                ),
            ],
          ),
          if (filtersActive) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: PatrolColors.ember.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: PatrolColors.ember.withValues(alpha: 0.3),
                ),
              ),
              child: const Text(
                'Filters active',
                style: TextStyle(fontSize: 10, color: PatrolColors.ember),
              ),
            ),
            TextButton(
              onPressed: ref.read(logProvider.notifier).resetLogUiState,
              child: const Text('Reset', style: TextStyle(fontSize: 10)),
            ),
          ],
          Text(
            lineLabel,
            style: const TextStyle(fontSize: 10, color: PatrolColors.steel),
          ),
          IconButton(
            onPressed: filtered.isEmpty
                ? null
                : () {
                    final text = filtered
                        .map(
                          (l) =>
                              '[${l.streamType.name}] ${sanitizeLogText(l.text)}',
                        )
                        .join('\n');
                    Clipboard.setData(ClipboardData(text: text));
                    ref
                        .read(runnerProvider.notifier)
                        .showSnackbar('Logs copied');
                  },
            icon: const Icon(Icons.copy, size: 12),
            tooltip: 'Copy visible logs',
          ),
          IconButton(
            onPressed: logState.logs.isEmpty
                ? null
                : () => ref.read(logProvider.notifier).clearLogs(),
            icon: const Icon(Icons.delete_outline, size: 12),
            tooltip: 'Clear all logs (⌘K)',
          ),
        ],
      ),
    );
  }
}

class _FilterMenu extends ConsumerWidget {
  const _FilterMenu({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(logProvider).logFilters;
    final notifier = ref.read(logProvider.notifier);

    return Material(
      elevation: 8,
      color: PatrolColors.mist,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PatrolColors.pebble),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'FILTER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: PatrolColors.steel,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    notifier.resetLogUiState();
                    onClose();
                  },
                  child: const Text('Reset', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Mode', style: TextStyle(fontSize: 10, color: PatrolColors.steel)),
            Row(
              children: LogFilterMode.values.map((mode) {
                final selected = filters.mode == mode;
                return Expanded(
                  child: TextButton(
                    onPressed: () => notifier.setLogFilterMode(mode),
                    style: TextButton.styleFrom(
                      backgroundColor:
                          selected ? PatrolColors.fog : Colors.transparent,
                      foregroundColor:
                          selected ? PatrolColors.ink : PatrolColors.steel,
                    ),
                    child: Text(
                      mode == LogFilterMode.include ? 'Show only' : 'Hide',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            const Text('Sources', style: TextStyle(fontSize: 10, color: PatrolColors.steel)),
            ...LogFilterKey.values.map((key) {
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  logFilterLabels[key]!,
                  style: const TextStyle(fontSize: 12),
                ),
                value: filters.sources[key],
                onChanged: (_) => notifier.toggleLogFilterSource(key),
              );
            }),
            const Text('Stream', style: TextStyle(fontSize: 10, color: PatrolColors.steel)),
            ...LogStreamFilter.values.map((stream) {
              return RadioListTile<LogStreamFilter>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  stream.name,
                  style: const TextStyle(fontSize: 12),
                ),
                value: stream,
                groupValue: filters.stream,
                onChanged: (value) {
                  if (value != null) notifier.setLogStreamFilter(value);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _EmptyLogsState extends ConsumerWidget {
  const _EmptyLogsState({required this.sessionBusy});

  final bool sessionBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logState = ref.watch(logProvider);
    if (logState.logs.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Logs exist, but filters hide them.',
              style: TextStyle(fontSize: 10, color: PatrolColors.steel),
            ),
            TextButton(
              onPressed: ref.read(logProvider.notifier).resetLogUiState,
              child: const Text('Reset filters'),
            ),
          ],
        ),
      );
    }

    if (sessionBusy) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(height: 8),
            Text('Starting...', style: TextStyle(fontSize: 10, color: PatrolColors.steel)),
          ],
        ),
      );
    }

    return const Center(child: _SessionDashboard());
  }
}

class _SessionDashboard extends ConsumerWidget {
  const _SessionDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    final runner = ref.watch(runnerProvider);

    final runDisabled = getRunDisabledReason(
      hasProject: app.currentProject != null,
      hasSelectedFile: app.selectedFile != null,
      isRunning: runner.isRunning,
      selectedDevice: runner.selectedDevice,
      currentRun: runner.currentRun,
    );
    final queueDisabled = getQueueRunDisabledReason(
      hasProject: app.currentProject != null,
      hasTestFiles: app.testFiles.isNotEmpty,
      isRunning: runner.isRunning,
      selectedDevice: runner.selectedDevice,
      currentRun: runner.currentRun,
    );

    final queueCount = app.selectedFileIds.isNotEmpty
        ? app.selectedFileIds.length
        : app.testFiles.length;
    final health = app.healthWarningCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dashboardRow(
          'Simulator',
          runner.selectedDevice?.name ?? 'None selected',
        ),
        _dashboardRow(
          'Active file',
          app.selectedFile != null
              ? middleTruncate(app.selectedFile!.fileName, 36)
              : 'None',
        ),
        _dashboardRow('Selected', '$queueCount file${queueCount == 1 ? '' : 's'}'),
        _dashboardRow(
          'Health',
          health == null
              ? '—'
              : health == 0
                  ? 'All checks passed'
                  : '$health warning${health == 1 ? '' : 's'}',
        ),
          _dashboardRow(
          'Last run',
          runner.currentRun != null
              ? '${runner.currentRun!.status.name} · ${runner.currentRun!.targetFile?.split('/').last ?? 'suite'}'
              : 'None yet',
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dashboardButton(
              label: 'Test',
              color: PatrolColors.psPassed,
              enabled: runDisabled == null,
              onPressed: () => ref.read(runnerProvider.notifier).runSelected(),
            ),
            const SizedBox(width: 8),
            _dashboardButton(
              label: 'Test All',
              color: PatrolColors.sky400,
              enabled: queueDisabled == null,
              onPressed: () => ref.read(runnerProvider.notifier).runAll(),
            ),
            const SizedBox(width: 8),
            _dashboardButton(
              label: 'Develop All',
              color: PatrolColors.violet400,
              enabled: queueDisabled == null,
              onPressed: () =>
                  ref.read(runnerProvider.notifier).developSuite(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dashboardRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 10, color: PatrolColors.steel),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: PatrolColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardButton({
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          backgroundColor: color.withValues(alpha: 0.15),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        child: Text(label, style: const TextStyle(fontSize: 10)),
      ),
    );
  }
}