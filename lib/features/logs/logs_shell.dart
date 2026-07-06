import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../providers/failed_logs_provider.dart';
import '../../widgets/patrol_components.dart';
import 'failed_logs_panel.dart';
import 'logs_panel.dart';

enum LogsShellTab { live, failed }

class LogsShell extends ConsumerStatefulWidget {
  const LogsShell({super.key, this.searchFocusNode});

  final FocusNode? searchFocusNode;

  @override
  ConsumerState<LogsShell> createState() => _LogsShellState();
}

class _LogsShellState extends ConsumerState<LogsShell> {
  LogsShellTab _tab = LogsShellTab.live;

  @override
  Widget build(BuildContext context) {
    final failedCount = ref.watch(failedLogsProvider).entries.length;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: PatrolColors.obsidian.withValues(alpha: 0.35),
            border: Border(
              bottom: BorderSide(color: PatrolColors.pebble.withValues(alpha: 0.7)),
            ),
          ),
          child: Row(
            children: [
              PatrolPanelTab(
                label: 'Live',
                icon: Icons.terminal_rounded,
                selected: _tab == LogsShellTab.live,
                onTap: () => setState(() => _tab = LogsShellTab.live),
              ),
              PatrolPanelTab(
                label: 'Failed',
                icon: Icons.error_outline_rounded,
                badge: failedCount > 0 ? 'FAILED ($failedCount)' : 'FAILED',
                selected: _tab == LogsShellTab.failed,
                onTap: () => setState(() => _tab = LogsShellTab.failed),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (_tab) {
            LogsShellTab.live => LogsPanel(searchFocusNode: widget.searchFocusNode),
            LogsShellTab.failed => const FailedLogsPanel(),
          },
        ),
      ],
    );
  }
}