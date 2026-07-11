import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/accessible_icon_button.dart';
import '../../widgets/collapsible_panel.dart';
import '../../widgets/panel_resize_handle.dart';
import '../../widgets/patrol_card.dart';
import '../../widgets/patrol_components.dart';
import '../../widgets/snackbar_overlay.dart';
import '../health/environment_health.dart';
import '../history/run_history.dart';
import '../logs/logs_shell.dart';
import '../recordings/recordings_panel.dart';
import '../runner/run_toolbar.dart';
import '../runner/workflow_status_strip.dart';
import '../settings/settings_screen.dart';
import '../tests/test_explorer.dart';

enum WorkspacePanelTab { tests, recordings, history, health }

const double _shellPadding = 12;
const double _panelGutter = 12;

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  WorkspacePanelTab _workspaceTab = WorkspacePanelTab.tests;
  bool _showSettings = false;
  bool _settingsDirty = false;
  bool _settingsSaving = false;
  final _settingsSaveNotifier = SettingsSaveNotifier();
  final _logSearchFocus = FocusNode();

  double _rightPanelWidth = rightPanelDefaultWidth;
  double _logsPanelWidth = logsPanelDefaultWidth;
  bool _logsCollapsed = false;
  bool _rightCollapsed = false;
  bool _layoutInitialized = false;

  @override
  void dispose() {
    _logSearchFocus.dispose();
    super.dispose();
  }

  void _initLayoutFromSettings(AppSettings settings) {
    _rightPanelWidth =
        clampRightPanelWidth(settings.rightPanelWidth.toDouble());
    _logsCollapsed = false;
    _rightCollapsed = false;
    _logsPanelWidth = clampLogsPanelWidth(
      settings.logsPanelWidth.toDouble(),
      totalWidth: MediaQuery.sizeOf(context).width,
      rightWidth: _rightPanelWidth,
      logsCollapsed: _logsCollapsed,
      rightCollapsed: _rightCollapsed,
    );
    _layoutInitialized = true;
  }

  void _persistLayout() {
    ref.read(settingsProvider.notifier).updatePartial({
      'rightPanelWidth': _rightPanelWidth.round(),
      'logsPanelWidth': _logsPanelWidth.round(),
      'logsCollapsed': _logsCollapsed,
      'rightCollapsed': _rightCollapsed,
    });
  }

  void _clampLogsToViewport(double totalWidth) {
    _logsPanelWidth = clampLogsPanelWidth(
      _logsPanelWidth,
      totalWidth: totalWidth,
      rightWidth: _rightPanelWidth,
      logsCollapsed: _logsCollapsed,
      rightCollapsed: _rightCollapsed,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ⚡ Bolt: Select specific fields instead of entire state objects to prevent AppShell from rebuilding
    // when unrelated state changes (like test updates during a run).
    final healthWarningCount = ref.watch(appProvider.select((a) => a.healthWarningCount));
    final settings = ref.watch(settingsProvider.select((s) => s.settings));
    final totalWidth = MediaQuery.sizeOf(context).width;

    if (ref.watch(settingsProvider.select((s) => s.loaded)) && !_layoutInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _initLayoutFromSettings(settings));
      });
    }

    ref.listen(settingsProvider.select((s) => s.settings.rightPanelWidth),
        (prev, next) {
      if (!_layoutInitialized) return;
      setState(() => _rightPanelWidth = clampRightPanelWidth(next.toDouble()));
    });
    ref.listen(settingsProvider.select((s) => s.settings.logsCollapsed),
        (prev, next) {
      if (!_layoutInitialized) return;
      setState(() => _logsCollapsed = next);
    });
    ref.listen(settingsProvider.select((s) => s.settings.rightCollapsed),
        (prev, next) {
      if (!_layoutInitialized) return;
      setState(() => _rightCollapsed = next);
    });

    return SnackbarOverlay(
      child: Scaffold(
        backgroundColor: PatrolColors.obsidian,
        body: Stack(
          children: [
            Column(
              children: [
                RunToolbar(
                  onOpenProject: () => ref.read(appProvider.notifier).openProject(),
                  onRefreshTests: () => ref.read(appProvider.notifier).scanTests(),
                  onOpenSettings: () => setState(() => _showSettings = true),
                ),
                const WorkflowStatusStrip(),
                Expanded(
                  child: Semantics(
                    container: true,
                    label: 'Patroller workspace',
                    child: Padding(
                      padding: const EdgeInsets.all(_shellPadding),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final viewportWidth = width + (_shellPadding * 2);
                          final clampedLogs = clampLogsPanelWidth(
                            _logsPanelWidth,
                            totalWidth: viewportWidth,
                            rightWidth: _rightPanelWidth,
                            logsCollapsed: _logsCollapsed,
                            rightCollapsed: _rightCollapsed,
                          );

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildLogsColumn(clampedLogs, viewportWidth),
                              const SizedBox(width: _panelGutter),
                              _buildWorkspaceColumn(
                                healthState: ref.watch(healthProvider),
                                healthWarningCount: healthWarningCount,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_showSettings) _settingsModal(settings),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsColumn(double clampedLogs, double viewportWidth) {
    if (_logsCollapsed) {
      return PatrolCard(
        padding: EdgeInsets.zero,
        child: CollapsiblePanelRail(
          label: 'Logs',
          icon: Icons.terminal,
          onExpand: () {
            setState(() => _logsCollapsed = false);
            _persistLayout();
          },
        ),
      );
    }

    return SizedBox(
      width: clampedLogs,
      child: Stack(
        children: [
          PatrolCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                CollapsiblePanelHeader(
                  title: 'Logs',
                  onCollapse: () {
                    setState(() => _logsCollapsed = true);
                    _persistLayout();
                  },
                ),
                Expanded(
                  child: LogsShell(searchFocusNode: _logSearchFocus),
                ),
              ],
            ),
          ),
          PanelResizeHandle(
            edge: PanelResizeEdge.right,
            onDrag: (delta) {
              setState(() {
                _logsPanelWidth = clampLogsPanelWidth(
                  _logsPanelWidth + delta,
                  totalWidth: viewportWidth,
                  rightWidth: _rightPanelWidth,
                  logsCollapsed: _logsCollapsed,
                  rightCollapsed: _rightCollapsed,
                );
              });
            },
            onDragEnd: (_) => _persistLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceColumn({
    required HealthState healthState,
    required int? healthWarningCount,
  }) {
    final healthWarnings =
        healthState.warningCount ?? healthWarningCount ?? 0;
    if (_rightCollapsed) {
      return PatrolCard(
        padding: EdgeInsets.zero,
        child: CollapsiblePanelRail(
          label: 'Workspace',
          icon: Icons.dashboard_outlined,
          edge: PanelEdge.right,
          onExpand: () {
            setState(() => _rightCollapsed = false);
            _persistLayout();
          },
        ),
      );
    }

    return Expanded(
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: _rightPanelWidth),
        child: Stack(
          children: [
            PanelResizeHandle(
              onDrag: (delta) {
                setState(() {
                  _rightPanelWidth = clampRightPanelWidth(
                    _rightPanelWidth - delta,
                  );
                });
              },
              onDragEnd: (_) => _persistLayout(),
            ),
            PatrolCard(
              child: Column(
                children: [
                  _WorkspacePanelTabs(
                    selected: _workspaceTab,
                    healthWarnings: healthWarnings,
                    onSelected: (tab) => setState(() => _workspaceTab = tab),
                    onCollapse: () {
                      setState(() => _rightCollapsed = true);
                      _persistLayout();
                    },
                  ),
                  Expanded(
                    child: switch (_workspaceTab) {
                      WorkspacePanelTab.tests => TestExplorer(
                          onRefresh: () =>
                              ref.read(appProvider.notifier).scanTests(),
                        ),
                      WorkspacePanelTab.recordings => const RecordingsPanel(),
                      WorkspacePanelTab.history => const RunHistory(),
                      WorkspacePanelTab.health => const EnvironmentHealth(),
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsModal(AppSettings settings) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
            child: PatrolCard(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 20,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: PatrolColors.pebble),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_settingsDirty) ...[
                          const SizedBox(width: 12),
                          const Text(
                            'Unsaved changes',
                            style: TextStyle(
                              fontSize: 10,
                              color: PatrolColors.ember,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const Spacer(),
                        AccessibleIconButton(
                          icon: Icons.close,
                          label: 'Close settings',
                          onPressed: _requestCloseSettings,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SettingsScreen(
                      onDirtyChanged: (dirty) =>
                          setState(() => _settingsDirty = dirty),
                      onSavingChanged: (saving) =>
                          setState(() => _settingsSaving = saving),
                      saveNotifier: _settingsSaveNotifier,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: PatrolColors.pebble),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _requestCloseSettings,
                          child: const Text('Close'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: (!_settingsDirty || _settingsSaving)
                              ? null
                              : () async {
                                  final saved =
                                      await _settingsSaveNotifier.save?.call();
                                  if (saved == true && mounted) {
                                    setState(() => _showSettings = false);
                                  }
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: PatrolColors.snow,
                            foregroundColor: PatrolColors.obsidian,
                          ),
                          child: Text(
                            _settingsSaving ? 'Saving...' : 'Save Settings',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _requestCloseSettings() {
    setState(() => _showSettings = false);
  }
}

class _WorkspacePanelTabs extends StatelessWidget {
  const _WorkspacePanelTabs({
    required this.selected,
    required this.healthWarnings,
    required this.onSelected,
    required this.onCollapse,
  });

  final WorkspacePanelTab selected;
  final int healthWarnings;
  final ValueChanged<WorkspacePanelTab> onSelected;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PatrolColors.obsidian.withValues(alpha: 0.35),
        border: Border(
          bottom: BorderSide(color: PatrolColors.pebble.withValues(alpha: 0.7)),
        ),
      ),
      child: Row(
        children: [
          ...WorkspacePanelTab.values.map((tab) {
            final isSelected = selected == tab;
            final label = switch (tab) {
              WorkspacePanelTab.tests => 'Tests',
              WorkspacePanelTab.recordings => 'Record',
              WorkspacePanelTab.history => 'History',
              WorkspacePanelTab.health => 'Health',
            };
            final badge = tab == WorkspacePanelTab.health && healthWarnings > 0
                ? 'HEALTH ($healthWarnings)'
                : null;
            final icon = switch (tab) {
              WorkspacePanelTab.tests => Icons.science_outlined,
              WorkspacePanelTab.recordings => Icons.fiber_manual_record_outlined,
              WorkspacePanelTab.history => Icons.history_rounded,
              WorkspacePanelTab.health => Icons.monitor_heart_outlined,
            };
            final tabColor = switch (tab) {
              WorkspacePanelTab.tests => PatrolColors.sky400,
              WorkspacePanelTab.recordings => PatrolColors.amber,
              WorkspacePanelTab.history => PatrolColors.violet400,
              WorkspacePanelTab.health => PatrolColors.orange400,
            };

            return PatrolPanelTab(
              label: label,
              icon: icon,
              selected: isSelected,
              badge: badge,
              color: tabColor,
              onTap: () => onSelected(tab),
            );
          }),
          const Spacer(),
          AccessibleIconButton(
            icon: Icons.chevron_right,
            label: 'Collapse workspace panel',
            onPressed: onCollapse,
            size: 16,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}