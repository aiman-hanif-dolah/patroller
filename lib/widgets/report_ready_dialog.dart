import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/patrol_colors.dart';
import '../providers/runner_provider.dart';
import '../services/report_open.dart';

/// Modal shown when a Patrol HTML report has been generated.
class ReportReadyDialog extends StatelessWidget {
  const ReportReadyDialog({
    super.key,
    required this.prompt,
    required this.onDismiss,
  });

  final ReportPrompt prompt;
  final VoidCallback onDismiss;

  static Future<void> show(
    BuildContext context, {
    required ReportPrompt prompt,
    required VoidCallback onDismiss,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ReportReadyDialog(
        prompt: prompt,
        onDismiss: () {
          Navigator.of(ctx).pop();
          onDismiss();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final failed = prompt.failed;
    final passed = prompt.passed;
    final summary = failed > 0
        ? '$passed passed · $failed failed'
        : (passed > 0 ? 'All $passed scenarios passed' : 'Report ready');

    return AlertDialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.border),
      ),
      title: Row(
        children: [
          Icon(
            failed > 0 ? Icons.assessment_outlined : Icons.task_alt,
            color: failed > 0 ? PatrolColors.psFailed : PatrolColors.psPassed,
            size: 22,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Patrol report ready'),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This is the generated report for the Patrol tests you ran.',
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: p.text,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prompt.projectName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: p.text,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    style: TextStyle(
                      fontSize: 12,
                      color: failed > 0
                          ? PatrolColors.psFailed
                          : PatrolColors.psPassed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (prompt.queueLabel != null &&
                      prompt.queueLabel!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      prompt.queueLabel!,
                      style: TextStyle(fontSize: 11, color: p.textMuted),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SelectableText(
                    prompt.path,
                    style: TextStyle(
                      fontFamily: 'Menlo',
                      fontSize: 10,
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Open it in your browser to review pass/fail details.',
              style: TextStyle(fontSize: 12, color: p.textMuted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: prompt.path));
          },
          child: const Text('Copy path'),
        ),
        TextButton(
          onPressed: () async {
            try {
              await revealHtmlReport(prompt.path);
            } catch (_) {}
          },
          child: Text(
            Platform.isMacOS
                ? 'Show in Finder'
                : (Platform.isWindows ? 'Show in Explorer' : 'Show in folder'),
          ),
        ),
        TextButton(
          onPressed: onDismiss,
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () async {
            try {
              await openHtmlReport(prompt.path);
              onDismiss();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not open report: $e')),
                );
              }
            }
          },
          icon: const Icon(Icons.open_in_browser, size: 16),
          label: const Text('Open report'),
        ),
      ],
    );
  }
}
