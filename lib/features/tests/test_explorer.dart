import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/runner_helpers.dart';
import '../../domain/simulator_driver_readiness.dart' show testsFilterLabel;
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/runner_provider.dart';
import '../../providers/test_run_state_provider.dart';
import '../../widgets/accessible_icon_button.dart';
import '../../widgets/patrol_components.dart';
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
  String _flowFilter = kAllFlowsFilter;
  final _expandedFiles = <String>{};

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final app = ref.watch(appProvider);
    final runner = ref.watch(runnerProvider);
    final activeRunFile = ref.watch(activeRunFileProvider);
    final suiteCtx = ref.watch(suiteContextProvider);
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
    final runnable = runnableTestFiles(testFiles);
    final runnableTests =
        runnable.fold<int>(0, (sum, f) => sum + f.detectedTestCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ExplorerHeader(
          runnableFiles: runnable.length,
          runnableTests: runnableTests,
          totalFiles: testFiles.length,
          filteredCount: filtered.length,
          isFiltered: _search.isNotEmpty ||
              _filterChip != 'all' ||
              !isAllFlowsFilter(_flowFilter),
          isScanning: app.isScanning,
          onRefresh: widget.onRefresh,
        ),
        if (selectedFileIds.isNotEmpty)
          _SelectionBanner(
            count: selectedFileIds.length,
            onClear: () => ref.read(appProvider.notifier).selectAllFiles(false),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: TextStyle(fontSize: 12, color: p.text),
            decoration: InputDecoration(
              hintText: 'Search tests...',
              hintStyle: TextStyle(fontSize: 12, color: p.textMuted),
              prefixIcon: Icon(Icons.search_rounded, size: 16, color: p.textMuted),
              isDense: true,
              filled: true,
              fillColor: p.surfaceMuted,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PatrolRadius.chip),
                borderSide: BorderSide(color: p.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PatrolRadius.chip),
                borderSide: BorderSide(color: p.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(PatrolRadius.chip),
                borderSide: const BorderSide(color: PatrolColors.amber, width: 1.5),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['all', 'runnable', 'passed', 'failed', 'never', 'selected']
                  .map(
                (chip) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: PatrolFilterPill(
                    label: testsFilterLabel(chip),
                    selected: _filterChip == chip,
                    color: switch (chip) {
                      'all' => PatrolPalette.of(context).textMuted,
                      'runnable' => PatrolColors.sky400,
                      'passed' => PatrolColors.psPassed,
                      'failed' => PatrolColors.psFailed,
                      'never' => PatrolColors.violet400,
                      'selected' => PatrolColors.amber,
                      _ => null,
                    },
                    onTap: () => setState(() => _filterChip = chip),
                  ),
                ),
              ).toList(),
            ),
          ),
        ),
        _buildFlowDropdown(testFiles),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _filterChip == 'selected'
                        ? 'No files selected for Test All'
                        : 'No matching tests',
                    style: TextStyle(fontSize: 12, color: p.textMuted),
                  ),
                )
              : ListView.separated(
                  primary: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final file = filtered[index];
                    final isSelected =
                        app.selectedFile?.absolutePath == file.absolutePath;
                    final isActiveRun =
                        activeRunFile?.absolutePath == file.absolutePath;
                    final isInSuite = suiteCtx != null &&
                        suiteCtx.files.any((f) => f.absolutePath == file.absolutePath);
                    final isSuiteCurrent = suiteCtx?.current?.absolutePath == file.absolutePath;
                    final isRunningFile = (isActiveRun || (isInSuite && isSuiteCurrent)) &&
                        (runner.isRunning ||
                            file.lastRunStatus == TestStatus.running);
                    final isMarkedSelected =
                        selectedFileIds.contains(file.absolutePath);
                    final isHelper = isHelperTestFile(file);
                    final expanded = _expandedFiles.contains(file.absolutePath);

                    return Column(
                      children: [
                        _TestFileRow(
                          file: file,
                          isSelected: isSelected,
                          isRunning: isRunningFile,
                          isMarkedSelected: isMarkedSelected,
                          isHelper: isHelper,
                          isExpanded: expanded,
                          onSelectFile: () =>
                              ref.read(appProvider.notifier).setSelectedFile(file),
                          onToggleSelection: () => ref
                              .read(appProvider.notifier)
                              .toggleFileSelection(file.absolutePath),
                          onToggleExpand: file.detectedTests.isEmpty
                              ? null
                              : () {
                                  setState(() {
                                    if (expanded) {
                                      _expandedFiles.remove(file.absolutePath);
                                    } else {
                                      _expandedFiles.add(file.absolutePath);
                                    }
                                  });
                                },
                        ),
                        if (expanded)
                          ...file.detectedTests.map((test) {
                            final testSelected = app.selectedTestCase == test;
                            return _TestCaseRow(
                              test: test,
                              isSelected: testSelected,
                              onTap: () => ref
                                  .read(appProvider.notifier)
                                  .setSelectedTestCase(test),
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
    if (!isAllFlowsFilter(_flowFilter)) {
      result = result.where((f) => f.folderPath.startsWith(_flowFilter)).toList();
    }
    switch (_filterChip) {
      case 'runnable':
        result = runnableTestFiles(result);
      case 'passed':
        result = result.where((f) => f.lastRunStatus == TestStatus.passed).toList();
      case 'failed':
        result = result.where((f) => f.lastRunStatus == TestStatus.failed).toList();
      case 'never':
        result = result.where((f) => f.lastRunTime == null).toList();
      case 'selected':
        result = result
            .where((f) => selectedFileIds.contains(f.absolutePath))
            .toList();
    }
    return result;
  }

  Widget _buildFlowDropdown(List<TestFile> files) {
    final p = PatrolPalette.of(context);
    final flows = <String>{};
    for (final f in files) {
      if (f.folderPath.isNotEmpty) {
        final top = f.folderPath.split('/').first;
        flows.add(top);
      }
    }
    if (flows.isEmpty) return const SizedBox.shrink();

    final sortedFlows = flows.toList()..sort();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          decoration: BoxDecoration(
            color: p.surfaceMuted,
            borderRadius: BorderRadius.circular(PatrolRadius.chip),
            border: Border.all(
              color: !isAllFlowsFilter(_flowFilter)
                  ? PatrolColors.amber.withValues(alpha: 0.5)
                  : p.border,
            ),
            boxShadow: !isAllFlowsFilter(_flowFilter)
                ? PatrolShadows.glow(PatrolColors.amber, blur: 6)
                : null,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _flowFilter,
              isDense: true,
              isExpanded: true,
              dropdownColor: p.fill,
              menuMaxHeight: 260,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: !isAllFlowsFilter(_flowFilter)
                    ? PatrolColors.amber
                    : p.textMuted,
              ),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: !isAllFlowsFilter(_flowFilter)
                    ? PatrolColors.amber
                    : p.textMuted,
              ),
              selectedItemBuilder: (context) {
                return [
                  const Text('All flows'),
                  ...sortedFlows.map((flow) => Text(
                        flow,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: PatrolColors.amber,
                        ),
                      )),
                ];
              },
              items: [
                DropdownMenuItem<String>(
                  value: kAllFlowsFilter,
                  child: Row(
                    children: [
                      Icon(Icons.select_all_rounded, size: 14, color: p.textMuted),
                      const SizedBox(width: 8),
                      const Text('All flows'),
                    ],
                  ),
                ),
                ...sortedFlows.map(
                  (flow) => DropdownMenuItem<String>(
                    value: flow,
                    child: Row(
                      children: [
                        const Icon(Icons.play_circle_outline_rounded, size: 14, color: PatrolColors.sky400),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            flow,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _flowFilter = value);
                final notifier = ref.read(appProvider.notifier);
                if (isAllFlowsFilter(value)) {
                  notifier.selectAllFiles(true);
                } else {
                  notifier.selectFlow(value);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _messageState(
    String message, {
    String? subtitle,
    Widget? action,
  }) {
    final p = PatrolPalette.of(context);
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
                style: TextStyle(fontSize: 10, color: p.textMuted),
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

class _ExplorerHeader extends StatelessWidget {
  const _ExplorerHeader({
    required this.runnableFiles,
    required this.runnableTests,
    required this.totalFiles,
    required this.filteredCount,
    required this.isFiltered,
    required this.isScanning,
    this.onRefresh,
  });

  final int runnableFiles;
  final int runnableTests;
  final int totalFiles;
  final int filteredCount;
  final bool isFiltered;
  final bool isScanning;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final summary = isFiltered
        ? '$filteredCount shown · $runnableFiles runnable · $runnableTests tests'
        : '$runnableFiles runnable / $totalFiles files · $runnableTests tests';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        border: Border(
          bottom: BorderSide(color: p.border),
        ),
      ),
      child: Row(
        children: [
          const PatrolAvatar(icon: Icons.science_outlined, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PatrolEyebrow('Test explorer'),
                const SizedBox(height: 2),
                Text(
                  summary,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: p.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onRefresh != null)
            AccessibleIconButton(
              icon: Icons.refresh_rounded,
              label: 'Refresh test list',
              onPressed: onRefresh,
              size: 14,
              color: isScanning ? PatrolColors.amber : p.textMuted,
            ),
        ],
      ),
    );
  }
}

class _SelectionBanner extends StatelessWidget {
  const _SelectionBanner({
    required this.count,
    required this.onClear,
  });

  final int count;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: PatrolColors.amber.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: PatrolColors.amber.withValues(alpha: 0.25)),
        ),
      ),
      child: Row(
        children: [
          PatrolMetaChip(
            label: formatTestAllSelectionBanner(count),
            icon: Icons.checklist_rounded,
            accent: true,
          ),
          const Spacer(),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(foregroundColor: PatrolColors.signalBlue),
            child: const Text('Clear', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _TestFileRow extends StatelessWidget {
  const _TestFileRow({
    required this.file,
    required this.isSelected,
    required this.isRunning,
    required this.isMarkedSelected,
    required this.isHelper,
    required this.isExpanded,
    required this.onSelectFile,
    required this.onToggleSelection,
    this.onToggleExpand,
  });

  final TestFile file;
  final bool isSelected;
  final bool isRunning;
  final bool isMarkedSelected;
  final bool isHelper;
  final bool isExpanded;
  final VoidCallback onSelectFile;
  final VoidCallback onToggleSelection;
  final VoidCallback? onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final accent = _accentColor(
      isRunning: isRunning,
      isSelected: isSelected,
      status: file.lastRunStatus,
    );
    final background = isRunning
        ? PatrolColors.sky400.withValues(alpha: 0.12)
        : isSelected
            ? p.surfaceMuted
            : p.surface;
    final borderColor = isRunning
        ? PatrolColors.sky400.withValues(alpha: 0.35)
        : isSelected
            ? p.textSecondary.withValues(alpha: 0.45)
            : p.border;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelectFile,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(12),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 6, bottom: 8),
                child: Checkbox(
                  value: isMarkedSelected,
                  onChanged: (_) => onToggleSelection(),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: AccessibleIconButton(
                  icon: isExpanded ? Icons.expand_more : Icons.chevron_right,
                  label: isExpanded
                      ? 'Collapse ${file.fileName} tests'
                      : 'Expand ${file.fileName} tests',
                  onPressed: onToggleExpand,
                  size: 14,
                  color: onToggleExpand == null
                      ? p.textFaint
                      : p.textMuted,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10, right: 8),
                child: Icon(
                  isHelper ? Icons.extension_outlined : Icons.description_outlined,
                  size: 14,
                  color: isHelper ? p.textFaint : p.textSecondary,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8, right: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              file.fileName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isHelper
                                    ? p.textMuted
                                    : p.text,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          ..._trailingBadges(context, file, isRunning, isHelper),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _metadataChips(file),
                      ),
                    ],
                  ),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _trailingBadges(
    BuildContext context,
    TestFile file,
    bool isRunning,
    bool isHelper,
  ) {
    final badges = <Widget>[];
    if (isRunning) {
      badges.add(_InlineBadge(
        label: 'running',
        foreground: PatrolColors.sky400,
        background: PatrolColors.sky400.withValues(alpha: 0.12),
      ));
    }
    if (isHelper) {
      final p = PatrolPalette.of(context);
      badges.add(_InlineBadge(
        label: 'helper',
        foreground: p.textSecondary,
        background: p.surfaceMuted,
      ));
    }
    if (file.lastRunStatus != TestStatus.idle && !isRunning) {
      badges.add(StatusBadge(status: file.lastRunStatus.name));
    }
    return badges;
  }

  List<Widget> _metadataChips(TestFile file) {
    final folder = file.folderPath.isNotEmpty
        ? file.folderPath
        : file.relativePath.replaceAll(RegExp(r'/[^/]+$'), '');
    final chips = <Widget>[
      PatrolMetaChip(
        icon: Icons.folder_outlined,
        label: folder.isEmpty ? 'patrol_test' : folder,
      ),
      PatrolMetaChip(
        icon: Icons.science_outlined,
        label: file.detectedTestCount == 0
            ? '0 tests · helper file'
            : '${file.detectedTestCount} test${file.detectedTestCount == 1 ? '' : 's'}',
      ),
    ];
    if (file.lastRunStatus != TestStatus.idle) {
      chips.add(PatrolMetaChip(label: file.lastRunStatus.name));
    } else if (file.lastRunTime == null) {
      chips.add(const PatrolMetaChip(label: 'never run'));
    }
    return chips;
  }

  Color _accentColor({
    required bool isRunning,
    required bool isSelected,
    required TestStatus status,
  }) {
    if (isRunning) return PatrolColors.sky400;
    if (isSelected) return PatrolColors.amber;
    return switch (status) {
      TestStatus.passed => PatrolColors.psPassed,
      TestStatus.failed => PatrolColors.psFailed,
      TestStatus.cancelled => PatrolColors.psCancelled,
      TestStatus.running => PatrolColors.sky400,
      _ => Colors.transparent,
    };
  }
}

class _TestCaseRow extends StatelessWidget {
  const _TestCaseRow({
    required this.test,
    required this.isSelected,
    required this.onTap,
  });

  final TestCase test;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 28, top: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? p.surfaceMuted
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? p.border
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.subdirectory_arrow_right,
                  size: 12,
                  color: p.textFaint,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    test.testName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? p.text
                          : p.textSecondary,
                    ),
                  ),
                ),
                if (test.status != TestStatus.idle)
                  StatusBadge(status: test.status.name),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineBadge extends StatelessWidget {
  const _InlineBadge({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: foreground,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}