import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/crash_service.dart';

class CrashReportDialog extends StatefulWidget {
  const CrashReportDialog({
    super.key,
    required this.report,
    required this.onDismiss,
  });

  final CrashReport report;
  final VoidCallback onDismiss;

  static Future<void> showIfNeeded(BuildContext context) async {
    if (!CrashService.instance.hasPendingCrashReport()) return;

    final report = CrashService.instance.getLatestCrashReport();
    if (report == null) {
      CrashService.instance.clearCrashReport();
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CrashReportDialog(
        report: report,
        onDismiss: () {
          CrashService.instance.clearCrashReport();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  State<CrashReportDialog> createState() => _CrashReportDialogState();
}

class _CrashReportDialogState extends State<CrashReportDialog> {
  bool _copied = false;
  bool _showStackTrace = true;

  Future<void> _copyLogs() async {
    final formatted = widget.report.toFormattedString();
    await Clipboard.setData(ClipboardData(text: formatted));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _exportLogFile() async {
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Crash Log',
      fileName: 'patroller_crash_${DateTime.now().millisecondsSinceEpoch}.txt',
      type: FileType.custom,
      allowedExtensions: ['txt', 'log'],
    );

    if (result != null) {
      final file = File(result);
      await file.writeAsString(widget.report.toFormattedString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Crash log saved to $result')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgCard = isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade50;
    final codeBg = isDark ? const Color(0xFF11111B) : Colors.grey.shade900;
    final codeFg = isDark ? const Color(0xFFCDD6F4) : const Color(0xFFF8F8F2);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 680,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patroller Crashed Previously',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Here are the details of the crash that occurred during your last session.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Metadata Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: theme.hintColor),
                  const SizedBox(width: 6),
                  Text(
                    'Time: ${widget.report.timestamp}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (widget.report.library != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.code, size: 16, color: theme.hintColor),
                    const SizedBox(width: 6),
                    Text(
                      'Library: ${widget.report.library}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Error Header
            Text(
              'Error Message',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: SelectableText(
                widget.report.error,
                style: GoogleFonts.firaCode(
                  color: isDark ? Colors.red.shade300 : Colors.red.shade900,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Stack Trace Toggle & Content
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stack Trace',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _showStackTrace = !_showStackTrace),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        Text(
                          _showStackTrace ? 'Hide' : 'Show',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Icon(
                          _showStackTrace
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            if (_showStackTrace)
              Flexible(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: codeBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      widget.report.stackTrace.isEmpty
                          ? 'No stack trace available.'
                          : widget.report.stackTrace,
                      style: GoogleFonts.firaCode(
                        color: codeFg,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Footer Actions
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _copyLogs,
                  icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
                  label: Text(_copied ? 'Copied!' : 'Copy Log'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _exportLogFile,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export Log'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: widget.onDismiss,
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
