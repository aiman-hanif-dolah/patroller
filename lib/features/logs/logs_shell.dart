import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/failure_diagnosis.dart';
import '../../providers/failed_logs_provider.dart';
import '../../providers/runner_provider.dart';
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
    final p = PatrolPalette.of(context);
    final failedCount = ref.watch(failedLogsProvider).entries.length;
    final diagnosis = ref.watch(
      runnerProvider.select((s) => s.failureDiagnosis),
    );

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: p.surfaceMuted,
            border: Border(
              bottom: BorderSide(color: p.border),
            ),
          ),
          child: Padding(
            // Keep first/last tabs clear of the ~4px panel resize hit strip.
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                PatrolPanelTab(
                  label: 'Live',
                  icon: Icons.terminal_rounded,
                  selected: _tab == LogsShellTab.live,
                  color: PatrolColors.amber,
                  onTap: () => setState(() => _tab = LogsShellTab.live),
                ),
                PatrolPanelTab(
                  label: 'Failed',
                  icon: Icons.error_outline_rounded,
                  badge: failedCount > 0 ? 'FAILED ($failedCount)' : 'FAILED',
                  selected: _tab == LogsShellTab.failed,
                  color: PatrolColors.psFailed,
                  onTap: () => setState(() => _tab = LogsShellTab.failed),
                ),
              ],
            ),
          ),
        ),
        if (diagnosis != null) _FailureDiagnosisBanner(diagnosis: diagnosis),
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

class _FailureDiagnosisBanner extends ConsumerWidget {
  const _FailureDiagnosisBanner({required this.diagnosis});

  final FailureDiagnosis diagnosis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = PatrolPalette.of(context);
    final isAssertion = diagnosis.category == FailureCategory.assertion;
    final accent =
        isAssertion ? PatrolColors.ember : PatrolColors.psFailed;

    return Material(
      color: accent.withValues(alpha: 0.1),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: accent.withValues(alpha: 0.35)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isAssertion ? Icons.rule_folder_outlined : Icons.lightbulb_outline,
              size: 16,
              color: accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    diagnosis.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: p.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    diagnosis.summary,
                    style: TextStyle(fontSize: 11, color: p.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Likely fix: ${diagnosis.likelyFix}',
                    style: TextStyle(fontSize: 11, color: p.textMuted),
                  ),
                  if (diagnosis.copyCommand != null) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: PatrolColors.sky400,
                        ),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: diagnosis.copyCommand!),
                          );
                          ref
                              .read(runnerProvider.notifier)
                              .showSnackbar('Command copied');
                        },
                        icon: const Icon(Icons.copy, size: 12),
                        label: Text(
                          diagnosis.copyCommand!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              onPressed: () =>
                  ref.read(runnerProvider.notifier).dismissFailureDiagnosis(),
              icon: Icon(Icons.close, color: p.textMuted, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}