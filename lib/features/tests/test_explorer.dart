import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/runner_helpers.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../widgets/status_badge.dart';

class TestExplorer extends ConsumerStatefulWidget {
  const TestExplorer({super.key, this.onRefresh});

  final VoidCallback? onRefresh;

  @override
  ConsumerState<TestExplorer> createState() => _TestExplorerState();
}

class _TestExplorerState extends ConsumerState<TestExplorer> {
  String _search = '';
  String _filterChip = 'all';
  final _expandedFiles = <String>{};

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final testFiles = app.testFiles;
    final selectedFileIds = app.selectedFileIds;

    if (app.scanError != null && testFiles.isEmpty) {
      return _messageState(
        app.scanError!,
        action: widget.onRefresh == null
            ? null
            : TextButton.icon(
                onPressed: widget.onRefresh,
                icon: const Icon(Icons.refresh, size: 12),
                label: const Text('Retry scan'),
              ),
      );
    }

    if (testFiles.isEmpty && !app.isScanning) {
      return _messageState(
        'No Patrol tests found',
        subtitle: 'Check test directory setting',
        action: widget.onRefresh == null
            ? null
            : TextButton.icon(
                onPressed: widget.onRefresh,
                icon: const Icon(Icons.refresh, size: 12),
                label: const Text('Rescan'),
              ),
      );
    }

    if (app.isScanning && testFiles.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final filtered = _filteredFiles(testFiles, selectedFileIds);
    final totalTests =
        testFiles.fold<int>(0, (sum, f) => sum + f.detectedTestCount);
    final header = formatTestExplorerHeader(
      testFiles.length,
      totalTests,
      filtered.length,
      _search.isNotEmpty || _filterChip != 'all',
    );

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: PatrolColors.pebble)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(header, style: Theme.of(context).textTheme.labelSmall),
              ),
              if (widget.onRefresh != null)
                IconButton(
                  onPressed: widget.onRefresh,
                  icon: Icon(
                    Icons.refresh,
                    size: 12,
                    color: app.isScanning
                        ? PatrolColors.ash
                        : PatrolColors.steel,
                  ),
                ),
            ],
          ),
        ),
        if (selectedFileIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: PatrolColors.fog.withValues(alpha: 0.3),
              border: Border(
                bottom: BorderSide(color: PatrolColors.pebble.withValues(alpha: 0.6)),
              ),
            ),
            child: Row(
              children: [
                Text(
                  formatTestAllQueueBanner(selectedFileIds.length),
                  style: const TextStyle(fontSize: 10, color: PatrolColors.steel),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      ref.read(appProvider.notifier).selectAllFiles(false),
                  child: const Text('Clear', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Search tests...',
              prefixIcon: Icon(Icons.search, size: 14),
              isDense: true,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: ['all', 'passed', 'failed', 'never', 'queued'].map((chip) {
              final selected = _filterChip == chip;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(chip, style: const TextStyle(fontSize: 10)),
                  selected: selected,
                  onSelected: (_) => setState(() => _filterChip = chip),
                  backgroundColor: PatrolColors.fog,
                  selectedColor: PatrolColors.ink,
                  labelStyle: TextStyle(
                    color: selected ? PatrolColors.obsidian : PatrolColors.steel,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _filterChip == 'queued'
                        ? 'No files selected for Test All'
                        : 'No matching tests',
                    style: const TextStyle(fontSize: 12, color: PatrolColors.steel),
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final file = filtered[index];
                    final isSelected =
                        app.selectedFile?.absolutePath == file.absolutePath;
                    final isQueued =
                        selectedFileIds.contains(file.absolutePath);
                    final expanded = _expandedFiles.contains(file.absolutePath);

                    return Column(
                      children: [
                        InkWell(
                          onTap: () =>
                              ref.read(appProvider.notifier).setSelectedFile(file),
                          child: Container(
                            color: isSelected
                                ? PatrolColors.fog
                                : Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isQueued,
                                  onChanged: (_) => ref
                                      .read(appProvider.notifier)
                                      .toggleFileSelection(file.absolutePath),
                                ),
                                IconButton(
                                  onPressed: file.detectedTests.isEmpty
                                      ? null
                                      : () {
                                          setState(() {
                                            if (expanded) {
                                              _expandedFiles
                                                  .remove(file.absolutePath);
                                            } else {
                                              _expandedFiles
                                                  .add(file.absolutePath);
                                            }
                                          });
                                        },
                                  icon: Icon(
                                    expanded
                                        ? Icons.expand_more
                                        : Icons.chevron_right,
                                    size: 14,
                                  ),
                                ),
                                const Icon(Icons.description_outlined, size: 14),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              file.fileName,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: PatrolColors.ink,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (file.lastRunStatus != TestStatus.idle)
                                            StatusBadge(
                                              status: file.lastRunStatus.name,
                                            ),
                                        ],
                                      ),
                                      Text(
                                        _fileSubline(file),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: PatrolColors.steel,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (expanded)
                          ...file.detectedTests.map((test) {
                            final testSelected =
                                app.selectedTestCase == test;
                            return InkWell(
                              onTap: () => ref
                                  .read(appProvider.notifier)
                                  .setSelectedTestCase(test),
                              child: Container(
                                color: testSelected
                                    ? PatrolColors.fog.withValues(alpha: 0.5)
                                    : Colors.transparent,
                                padding: const EdgeInsets.only(
                                  left: 72,
                                  right: 12,
                                  top: 4,
                                  bottom: 4,
                                ),
                                child: Text(
                                  test.testName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: PatrolColors.graphite,
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  List<TestFile> _filteredFiles(
    List<TestFile> files,
    Set<String> selectedFileIds,
  ) {
    var result = files;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      result = result
          .where(
            (f) =>
                f.fileName.toLowerCase().contains(q) ||
                f.relativePath.toLowerCase().contains(q) ||
                f.detectedTests.any(
                  (t) => t.testName.toLowerCase().contains(q),
                ),
          )
          .toList();
    }
    switch (_filterChip) {
      case 'passed':
        result = result.where((f) => f.lastRunStatus == TestStatus.passed).toList();
      case 'failed':
        result = result.where((f) => f.lastRunStatus == TestStatus.failed).toList();
      case 'never':
        result = result.where((f) => f.lastRunTime == null).toList();
      case 'queued':
        result = result
            .where((f) => selectedFileIds.contains(f.absolutePath))
            .toList();
    }
    return result;
  }

  String _fileSubline(TestFile file) {
    final parts = <String>[
      file.folderPath.isNotEmpty
          ? file.folderPath
          : file.relativePath.replaceAll(RegExp(r'/[^/]+$'), ''),
      '${file.detectedTestCount} test${file.detectedTestCount == 1 ? '' : 's'}',
    ];
    if (file.lastRunStatus != TestStatus.idle) {
      parts.add(file.lastRunStatus.name);
    } else if (file.lastRunTime == null) {
      parts.add('never run');
    }
    return parts.join(' · ');
  }

  Widget _messageState(
    String message, {
    String? subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: PatrolColors.rose300),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: PatrolColors.steel),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 12),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

String formatTestAllQueueBanner(int queuedCount) {
  if (queuedCount == 0) return 'All files';
  return '$queuedCount file${queuedCount == 1 ? '' : 's'} selected for Test All';
}