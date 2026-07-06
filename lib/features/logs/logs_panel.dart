import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import '../../providers/settings_provider.dart';
import '../../widgets/accessible_icon_button.dart';


class LogsPanel extends ConsumerStatefulWidget {
  const LogsPanel({super.key, this.searchFocusNode});

  final FocusNode? searchFocusNode;

  @override
  ConsumerState<LogsPanel> createState() => _LogsPanelState();
}

class _LogsPanelState extends ConsumerState<LogsPanel> {
  static const _bottomThreshold = 56.0;

  final _scrollController = ScrollController();
  bool _showJumpToBottom = false;
  bool _showFilterMenu = false;
  bool _programmaticScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncJumpToBottomVisibility);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_syncJumpToBottomVisibility);
    _scrollController.dispose();
    super.dispose();
  }

  bool _isAtBottom() {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= _bottomThreshold;
  }

  void _syncJumpToBottomVisibility() {
    if (_programmaticScroll) return;
    final showJump = !_isAtBottom();
    if (showJump != _showJumpToBottom) {
      setState(() => _showJumpToBottom = showJump);
    }
  }

  void _scrollToBottom({bool resumeAutoScroll = false}) {
    _programmaticScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        _programmaticScroll = false;
        return;
      }
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
        _programmaticScroll = false;
        if (mounted) {
          setState(() => _showJumpToBottom = false);
        }
      });
    });
    if (resumeAutoScroll && !ref.read(logProvider).autoScroll) {
      ref.read(logProvider.notifier).setAutoScroll(true);
    }
  }

  bool _handleUserScroll(ScrollNotification notification) {
    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle &&
        !_isAtBottom() &&
        ref.read(logProvider).autoScroll) {
      ref.read(logProvider.notifier).setAutoScroll(false);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final logState = ref.watch(logProvider);
    final filteredLogs = ref.watch(filteredLogsProvider);
    final runner = ref.watch(runnerProvider);
    final sessionBusy = isSessionBusy(runner.isRunning, runner.currentRun);

    ref.listen(logProvider.select((s) => s.revision), (prev, next) {
      if (ref.read(logProvider).autoScroll) {
        _scrollToBottom();
      }
    });

    ref.listen(filteredLogsProvider, (prev, next) {
      if (prev == null || prev.length == next.length) return;
      if (ref.read(logProvider).autoScroll) {
        _scrollToBottom();
      } else {
        _syncJumpToBottomVisibility();
      }
    });

    return Column(
      children: [
        _LogsToolbar(
          searchFocusNode: widget.searchFocusNode,
          showFilterMenu: _showFilterMenu,
          showJumpToBottom: _showJumpToBottom,
          onJumpToBottom: () => _scrollToBottom(resumeAutoScroll: true),
          onToggleFilterMenu: () =>
              setState(() => _showFilterMenu = !_showFilterMenu),
        ),
        if (_showFilterMenu)
          _FilterPanel(
            onClose: () => setState(() => _showFilterMenu = false),
          ),
        Expanded(
          child: Stack(
            children: [
              if (filteredLogs.isEmpty)
                _EmptyLogsState(sessionBusy: sessionBusy)
              else
                Column(
                  children: [
                    const _LogColumnHeader(),
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _handleUserScroll,
                        child: Scrollbar(
                          controller: _scrollController,
                          child: SelectionArea(
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
                        ),
                      ),
                    ),
                  ],
                ),
              if (_showJumpToBottom)
                Positioned(
                  right: 20,
                  bottom: 12,
                  child: Semantics(
                    button: true,
                    label: 'Jump to bottom of logs',
                    child: FilledButton.icon(
                      onPressed: () => _scrollToBottom(resumeAutoScroll: true),
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
    if (isDependencyNoticeBlock(log)) {
      final countLabel = log.text.replaceFirst(dependencyNoticeBlockPrefix, '');
      return ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        title: Text(
          'Dependency notices ($countLabel)',
          style: const TextStyle(
            fontFamily: 'Menlo',
            fontSize: 11,
            color: PatrolColors.steel,
          ),
        ),
        children: [
          SelectableText(
            log.rawText ?? '',
            style: const TextStyle(
              fontFamily: 'Menlo',
              fontSize: 10,
              height: 1.4,
              color: PatrolColors.graphite,
            ),
          ),
        ],
      );
    }

    final category = classifyLog(log);
    final style = logCategoryStyles[category]!;
    final timestamp = formatLogTimestamp(log.timestamp);
    const messageStyle = TextStyle(
      fontFamily: 'Menlo',
      fontSize: 11,
      height: 1.5,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: PatrolColors.pebble.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _LogLineLayout.timeWidth,
            child: Text(
              timestamp,
              style: const TextStyle(
                fontFamily: 'Menlo',
                fontSize: 10,
                height: 1.5,
                color: PatrolColors.steel,
              ),
            ),
          ),
          const SizedBox(width: _LogLineLayout.gutter),
          _LogLabelBadge(style: style),
          const SizedBox(width: _LogLineLayout.gutter),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: messageStyle,
                children: buildLogTextSpans(
                  log.text,
                  defaultColor: style.text,
                  baseStyle: messageStyle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogLineLayout {
  static const double timeWidth = 52;
  static const double labelWidth = 56;
  static const double gutter = 8;
  static const double horizontalPadding = 8;
}

class _LogColumnHeader extends StatelessWidget {
  const _LogColumnHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        _LogLineLayout.horizontalPadding + 12,
        4,
        12,
        4,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PatrolColors.pebble)),
        color: Color(0x3309090B),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _LogLineLayout.timeWidth,
            child: Text(
              'TIME',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: PatrolColors.steel.withValues(alpha: 0.9),
              ),
            ),
          ),
          const SizedBox(width: _LogLineLayout.gutter),
          SizedBox(
            width: _LogLineLayout.labelWidth,
            child: Text(
              'LABEL',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: PatrolColors.steel.withValues(alpha: 0.9),
              ),
            ),
          ),
          const SizedBox(width: _LogLineLayout.gutter),
          const Expanded(
            child: Text(
              'MESSAGE',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: PatrolColors.steel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogLabelBadge extends StatelessWidget {
  const _LogLabelBadge({required this.style});

  final LogCategoryStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _LogLineLayout.labelWidth,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: style.tag.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: style.tag.withValues(alpha: 0.45)),
      ),
      child: Text(
        style.label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Menlo',
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: style.tag,
          height: 1.3,
        ),
      ),
    );
  }
}

class _LogsToolbar extends ConsumerWidget {
  const _LogsToolbar({
    this.searchFocusNode,
    required this.showFilterMenu,
    required this.showJumpToBottom,
    required this.onJumpToBottom,
    required this.onToggleFilterMenu,
  });

  final FocusNode? searchFocusNode;
  final bool showFilterMenu;
  final bool showJumpToBottom;
  final VoidCallback onJumpToBottom;
  final VoidCallback onToggleFilterMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logState = ref.watch(logProvider);
    final showRaw = ref.watch(settingsProvider).settings.showRawStderr;
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
          AccessibleIconButton(
            icon: logState.autoScroll ? Icons.pause : Icons.play_arrow,
            label: logState.autoScroll
                ? 'Pause auto-scroll'
                : 'Resume auto-scroll',
            onPressed: () {
              final next = !logState.autoScroll;
              ref.read(logProvider.notifier).setAutoScroll(next);
              if (next) onJumpToBottom();
            },
            size: 12,
          ),
          AccessibleIconButton(
            icon: Icons.arrow_downward,
            label: 'Jump to bottom of logs',
            color: showJumpToBottom ? PatrolColors.ink : PatrolColors.steel,
            onPressed: filtered.isEmpty ? null : onJumpToBottom,
            size: 12,
          ),
          AccessibleIconButton(
            icon: showFilterMenu ? Icons.filter_list_off : Icons.filter_list,
            label: showFilterMenu ? 'Hide log filters' : 'Show log filters',
            color: showFilterMenu || filtersActive
                ? PatrolColors.ink
                : PatrolColors.steel,
            onPressed: onToggleFilterMenu,
            size: 12,
          ),
          AccessibleIconButton(
            icon: showRaw ? Icons.article_outlined : Icons.article,
            label: showRaw ? 'Hide raw stderr' : 'Show raw stderr',
            color: showRaw ? PatrolColors.ink : PatrolColors.steel,
            onPressed: () => ref.read(settingsProvider.notifier).updatePartial({
              'showRawStderr': !showRaw,
            }),
            size: 12,
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
          AccessibleIconButton(
            icon: Icons.copy,
            label: 'Copy visible logs',
            onPressed: filtered.isEmpty
                ? null
                : () {
                    final text = filtered
                        .map(
                          (l) => '[${l.streamType.name}] ${l.exportText}',
                        )
                        .join('\n');
                    Clipboard.setData(ClipboardData(text: text));
                    ref
                        .read(runnerProvider.notifier)
                        .showSnackbar('Logs copied');
                  },
            size: 12,
          ),
          AccessibleIconButton(
            icon: Icons.delete_outline,
            label: 'Clear all logs',
            onPressed: logState.logs.isEmpty
                ? null
                : () => ref.read(logProvider.notifier).clearLogs(),
            size: 12,
          ),
        ],
      ),
    );
  }
}

class _FilterPanel extends ConsumerWidget {
  const _FilterPanel({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(logProvider).logFilters;
    final notifier = ref.read(logProvider.notifier);

    return Material(
      color: PatrolColors.fog,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 240),
        decoration: const BoxDecoration(
          color: PatrolColors.fog,
          border: Border(
            bottom: BorderSide(color: PatrolColors.pebble),
          ),
        ),
        child: Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'LOG FILTERS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: PatrolColors.steel,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: notifier.resetLogUiState,
                      child: const Text(
                        'Reset all',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                    AccessibleIconButton(
                      icon: Icons.close,
                      label: 'Close log filters',
                      onPressed: onClose,
                      size: 14,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 52,
                      child: Text(
                        'Mode',
                        style: TextStyle(fontSize: 10, color: PatrolColors.steel),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        children: LogFilterMode.values.map((mode) {
                          final selected = filters.mode == mode;
                          return ChoiceChip(
                            label: Text(
                              mode == LogFilterMode.include ? 'Show only' : 'Hide',
                              style: TextStyle(
                                fontSize: 10,
                                color: selected
                                    ? PatrolColors.ink
                                    : PatrolColors.steel,
                              ),
                            ),
                            selected: selected,
                            onSelected: (_) => notifier.setLogFilterMode(mode),
                            selectedColor: PatrolColors.fog,
                            backgroundColor: PatrolColors.fog,
                            side: BorderSide(
                              color: selected ? PatrolColors.ink : PatrolColors.graphite,
                            ),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 52,
                      child: Text(
                        'Stream',
                        style: TextStyle(fontSize: 10, color: PatrolColors.steel),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        children: LogStreamFilter.values.map((stream) {
                          final selected = filters.stream == stream;
                          return ChoiceChip(
                            label: Text(
                              stream.name,
                              style: TextStyle(
                                fontSize: 10,
                                color: selected
                                    ? PatrolColors.ink
                                    : PatrolColors.steel,
                              ),
                            ),
                            selected: selected,
                            onSelected: (_) =>
                                notifier.setLogStreamFilter(stream),
                            selectedColor: PatrolColors.fog,
                            backgroundColor: PatrolColors.fog,
                            side: BorderSide(
                              color: selected ? PatrolColors.ink : PatrolColors.graphite,
                            ),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 52,
                      child: Text(
                        'Sources',
                        style: TextStyle(fontSize: 10, color: PatrolColors.steel),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: LogFilterKey.values.map((key) {
                          final enabled = filters.sources[key] ?? true;
                          return FilterChip(
                            label: Text(
                              logFilterLabels[key]!,
                              style: TextStyle(
                                fontSize: 10,
                                color: enabled
                                    ? PatrolColors.ink
                                    : PatrolColors.steel,
                              ),
                            ),
                            selected: enabled,
                            onSelected: (_) =>
                                notifier.toggleLogFilterSource(key),
                            showCheckmark: false,
                            selectedColor: PatrolColors.fog,
                            backgroundColor: PatrolColors.fog,
                            side: BorderSide(
                              color: enabled ? PatrolColors.ink : PatrolColors.graphite,
                            ),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrollableCenteredBody extends StatelessWidget {
  const _ScrollableCenteredBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: child),
            ),
          ),
        );
      },
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
      return _ScrollableCenteredBody(
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
      return const _ScrollableCenteredBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(height: 8),
            Text(
              'Starting...',
              style: TextStyle(fontSize: 10, color: PatrolColors.steel),
            ),
          ],
        ),
      );
    }

    return const _ScrollableCenteredBody(child: _SessionDashboard());
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
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _dashboardButton(
              label: 'Test',
              color: PatrolColors.psPassed,
              enabled: runDisabled == null,
              onPressed: () => ref.read(runnerProvider.notifier).runSelected(),
            ),
            _dashboardButton(
              label: 'Test All',
              color: PatrolColors.sky400,
              enabled: queueDisabled == null,
              onPressed: () => ref.read(runnerProvider.notifier).runAll(),
            ),
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