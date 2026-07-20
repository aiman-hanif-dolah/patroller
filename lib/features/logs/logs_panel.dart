import 'dart:async';

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
  static const _autoScrollThrottle = Duration(milliseconds: 80);

  final _scrollController = ScrollController();
  bool _showJumpToBottom = false;
  bool _showFilterMenu = false;
  bool _programmaticScroll = false;
  bool _scrollPending = false;
  DateTime? _lastAutoScrollAt;

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

  void _scrollToBottom({bool resumeAutoScroll = false, bool force = false}) {
    if (!force) {
      final now = DateTime.now();
      final last = _lastAutoScrollAt;
      if (last != null && now.difference(last) < _autoScrollThrottle) {
        if (!_scrollPending) {
          _scrollPending = true;
          final wait = _autoScrollThrottle - now.difference(last);
          Future<void>.delayed(wait, () {
            _scrollPending = false;
            if (!mounted || !ref.read(logProvider).autoScroll) return;
            _scrollToBottom(force: true);
          });
        }
        return;
      }
      _lastAutoScrollAt = now;
    } else {
      _lastAutoScrollAt = DateTime.now();
    }

    _programmaticScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        _programmaticScroll = false;
        return;
      }
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      _programmaticScroll = false;
      if (mounted) {
        setState(() => _showJumpToBottom = false);
      }
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
    final p = PatrolPalette.of(context);
    final filteredLogs = ref.watch(filteredLogsProvider);
    final sessionBusy = ref.watch(
      runnerProvider.select(
        (s) => isSessionBusy(s.isRunning, s.currentRun),
      ),
    );

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
          onJumpToBottom: () => _scrollToBottom(resumeAutoScroll: true, force: true),
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
                      onPressed: () =>
                          _scrollToBottom(resumeAutoScroll: true, force: true),
                      icon: const Icon(Icons.arrow_downward, size: 12),
                      label: const Text('Jump to bottom'),
                      style: FilledButton.styleFrom(
                        backgroundColor: p.text,
                        foregroundColor: p.surface,
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
    final p = PatrolPalette.of(context);
    if (isDependencyNoticeBlock(log)) {
      return _DependencyNoticeLine(log: log);
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
          color: p.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _LogLineLayout.timeWidth,
            child: Text(
              timestamp,
              style: TextStyle(
                fontFamily: 'Menlo',
                fontSize: 10,
                height: 1.5,
                color: p.textMuted,
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

/// Collapsible dependency-notice summary.
///
/// Avoids [ExpansionTile]/[ListTile]: nested ListTiles under a colored
/// panel [DecoratedBox] assert about invisible ink, and expanding under a
/// parent [SelectionArea] can hit `RenderParagraph !debugNeedsLayout`.
class _DependencyNoticeLine extends StatefulWidget {
  const _DependencyNoticeLine({required this.log});

  final LogEvent log;

  @override
  State<_DependencyNoticeLine> createState() => _DependencyNoticeLineState();
}

class _DependencyNoticeLineState extends State<_DependencyNoticeLine> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final countLabel =
        widget.log.text.replaceFirst(dependencyNoticeBlockPrefix, '');
    final raw = widget.log.rawText ?? '';

    // Opt out of the parent SelectionArea so expand/collapse does not
    // re-register selectables mid-frame (framework selection assert).
    return SelectionContainer.disabled(
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Dependency notices ($countLabel)',
                        style: TextStyle(
                          fontFamily: 'Menlo',
                          fontSize: 11,
                          color: p.textMuted,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: p.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded && raw.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                // Nested SelectionArea owns selection for expanded text only.
                child: SelectionArea(
                  child: Text(
                    raw,
                    style: TextStyle(
                      fontFamily: 'Menlo',
                      fontSize: 10,
                      height: 1.4,
                      color: p.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
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
    final p = PatrolPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        _LogLineLayout.horizontalPadding + 12,
        4,
        12,
        4,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
        color: p.surfaceMuted,
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
                color: p.textMuted.withValues(alpha: 0.9),
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
                color: p.textMuted.withValues(alpha: 0.9),
              ),
            ),
          ),
          const SizedBox(width: _LogLineLayout.gutter),
          Expanded(
            child: Text(
              'MESSAGE',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: p.textMuted,
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
    final p = PatrolPalette.of(context);
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
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 420;
          final actions = <Widget>[
            Text(
              'LOGS',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: narrow ? 120 : 180,
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
            _LogsToolbarAction(
              icon: logState.autoScroll ? Icons.pause : Icons.play_arrow,
              text: logState.autoScroll ? 'Pause' : 'Resume',
              tooltip: logState.autoScroll
                  ? 'Pause auto-scroll'
                  : 'Resume auto-scroll',
              showLabel: !narrow,
              onPressed: () {
                final next = !logState.autoScroll;
                ref.read(logProvider.notifier).setAutoScroll(next);
                if (next) onJumpToBottom();
              },
            ),
            _LogsToolbarAction(
              icon: Icons.arrow_downward,
              text: 'Bottom',
              tooltip: 'Jump to bottom of logs',
              color: showJumpToBottom ? p.text : p.textMuted,
              showLabel: !narrow,
              onPressed: filtered.isEmpty ? null : onJumpToBottom,
            ),
            _LogsToolbarAction(
              icon: showFilterMenu ? Icons.filter_list_off : Icons.filter_list,
              text: 'Filter',
              tooltip: showFilterMenu ? 'Hide log filters' : 'Show log filters',
              color: showFilterMenu || filtersActive
                  ? p.text
                  : p.textMuted,
              showLabel: !narrow,
              onPressed: onToggleFilterMenu,
            ),
            _LogsToolbarAction(
              icon: showRaw ? Icons.article_outlined : Icons.article,
              text: 'Raw',
              tooltip: showRaw ? 'Hide raw stderr' : 'Show raw stderr',
              color: showRaw ? p.text : p.textMuted,
              showLabel: !narrow,
              onPressed: () => ref.read(settingsProvider.notifier).updatePartial({
                'showRawStderr': !showRaw,
              }),
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
              style: TextStyle(fontSize: 10, color: p.textMuted),
            ),
            _LogsToolbarAction(
              icon: Icons.copy,
              text: 'Copy',
              tooltip: 'Copy visible logs',
              showLabel: !narrow,
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
            ),
            _LogsToolbarAction(
              icon: Icons.delete_outline,
              text: 'Clear',
              tooltip: 'Clear all logs',
              showLabel: !narrow,
              onPressed: logState.logs.isEmpty
                  ? null
                  : () => ref.read(logProvider.notifier).clearLogs(),
            ),
          ];

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: actions),
          );
        },
      ),
    );
  }
}

/// Compact icon + text control for the logs toolbar (macOS density).
class _LogsToolbarAction extends StatelessWidget {
  const _LogsToolbarAction({
    required this.icon,
    required this.text,
    required this.tooltip,
    this.onPressed,
    this.color,
    this.showLabel = true,
  });

  final IconData icon;
  final String text;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final fg = color ?? p.textMuted;
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: fg,
            disabledForegroundColor: p.textMuted.withValues(alpha: 0.38),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: enabled ? fg : null),
              if (showLabel) ...[
                const SizedBox(width: 4),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: enabled ? fg : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterPanel extends ConsumerStatefulWidget {
  const _FilterPanel({required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends ConsumerState<_FilterPanel> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final filters = ref.watch(logProvider).logFilters;
    final notifier = ref.read(logProvider.notifier);

    return Material(
      color: p.surfaceMuted,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 240),
        decoration: BoxDecoration(
          color: p.surfaceMuted,
          border: Border(
            bottom: BorderSide(color: p.border),
          ),
        ),
        child: Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'LOG FILTERS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: p.textMuted,
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
                      onPressed: widget.onClose,
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
                    SizedBox(
                      width: 52,
                      child: Text(
                        'Mode',
                        style: TextStyle(fontSize: 10, color: p.textMuted),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        children: LogFilterMode.values.map((mode) {
                          final p = PatrolPalette.of(context);
                          final selected = filters.mode == mode;
                          return ChoiceChip(
                            label: Text(
                              mode == LogFilterMode.include ? 'Show only' : 'Hide',
                              style: TextStyle(
                                fontSize: 10,
                                color: selected
                                    ? p.text
                                    : p.textMuted,
                              ),
                            ),
                            selected: selected,
                            onSelected: (_) => notifier.setLogFilterMode(mode),
                            selectedColor: p.surface,
                            backgroundColor: p.surfaceMuted,
                            side: BorderSide(
                              color: selected ? p.text : p.border,
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
                    SizedBox(
                      width: 52,
                      child: Text(
                        'Stream',
                        style: TextStyle(fontSize: 10, color: p.textMuted),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        children: LogStreamFilter.values.map((stream) {
                          final p = PatrolPalette.of(context);
                          final selected = filters.stream == stream;
                          return ChoiceChip(
                            label: Text(
                              stream.name,
                              style: TextStyle(
                                fontSize: 10,
                                color: selected
                                    ? p.text
                                    : p.textMuted,
                              ),
                            ),
                            selected: selected,
                            onSelected: (_) =>
                                notifier.setLogStreamFilter(stream),
                            selectedColor: p.surface,
                            backgroundColor: p.surfaceMuted,
                            side: BorderSide(
                              color: selected ? p.text : p.border,
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
                    SizedBox(
                      width: 52,
                      child: Text(
                        'Sources',
                        style: TextStyle(fontSize: 10, color: p.textMuted),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: LogFilterKey.values.map((key) {
                          final p = PatrolPalette.of(context);
                          final enabled = filters.sources[key] ?? true;
                          return FilterChip(
                            label: Text(
                              logFilterLabels[key]!,
                              style: TextStyle(
                                fontSize: 10,
                                color: enabled
                                    ? p.text
                                    : p.textMuted,
                              ),
                            ),
                            selected: enabled,
                            onSelected: (_) =>
                                notifier.toggleLogFilterSource(key),
                            showCheckmark: false,
                            selectedColor: p.surface,
                            backgroundColor: p.surfaceMuted,
                            side: BorderSide(
                              color: enabled ? p.text : p.border,
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

class _ScrollableCenteredBody extends StatefulWidget {
  const _ScrollableCenteredBody({required this.child});

  final Widget child;

  @override
  State<_ScrollableCenteredBody> createState() =>
      _ScrollableCenteredBodyState();
}

class _ScrollableCenteredBodyState extends State<_ScrollableCenteredBody> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: widget.child),
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
      final p = PatrolPalette.of(context);
      return _ScrollableCenteredBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Logs exist, but filters hide them.',
              style: TextStyle(fontSize: 10, color: p.textMuted),
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
      final p = PatrolPalette.of(context);
      final lifecycle = resolveLifecycle(
        ref.watch(runnerProvider.select((s) => s.currentRun)),
      );
      final message = emptyLogsBusyMessage(lifecycle);
      return _ScrollableCenteredBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 10, color: p.textMuted),
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
    final p = PatrolPalette.of(context);
    final selectedFile =
        ref.watch(appProvider.select((s) => s.selectedFile));
    final testFilesLen =
        ref.watch(appProvider.select((s) => s.testFiles.length));
    final selectedFileIdsLen =
        ref.watch(appProvider.select((s) => s.selectedFileIds.length));
    final health = ref.watch(appProvider.select((s) => s.healthWarningCount));

    final selectedDevice =
        ref.watch(runnerProvider.select((s) => s.selectedDevice));
    final currentRun = ref.watch(runnerProvider.select((s) => s.currentRun));

    final queueCount =
        selectedFileIdsLen > 0 ? selectedFileIdsLen : testFilesLen;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dashboardRow(
          'Simulator',
          selectedDevice?.name ?? 'None selected',
          p,
        ),
        _dashboardRow(
          'Active file',
          selectedFile != null
              ? middleTruncate(selectedFile.fileName, 36)
              : 'None',
          p,
        ),
        _dashboardRow(
          'Selected',
          '$queueCount file${queueCount == 1 ? '' : 's'}',
          p,
        ),
        _dashboardRow(
          'Health',
          health == null
              ? '-'
              : health == 0
                  ? 'All checks passed'
                  : '$health warning${health == 1 ? '' : 's'}',
          p,
        ),
        _dashboardRow(
          'Last run',
          currentRun != null
              ? '${currentRun.status.name} · ${currentRun.targetFile?.split('/').last ?? 'suite'}'
              : 'None yet',
          p,
        ),
      ],
    );
  }

  Widget _dashboardRow(String label, String value, PatrolPalette p) {
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: p.textMuted),
            ),
          ),
          const SizedBox(width: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: p.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}