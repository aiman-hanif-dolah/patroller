import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/panel_resize_handle.dart';
import '../../widgets/patrol_card.dart';
import '../../widgets/snackbar_overlay.dart';
import '../devices/simulator_preview_panel.dart';
import '../health/environment_health.dart';
import '../history/run_history.dart';
import '../inspector/hierarchy_inspector.dart';
import '../logs/logs_panel.dart';
import '../recordings/recordings_panel.dart';
import '../runner/run_toolbar.dart';
import '../runner/workflow_status_strip.dart';
import '../settings/settings_screen.dart';
import '../tests/test_explorer.dart';

enum RightPanelTab { tests, inspector, recordings, history, health }

const double _shellPadding = 12;
const double _panelGutter = 12;

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  RightPanelTab _rightTab = RightPanelTab.tests;
  bool _showSettings = false;
  bool _settingsDirty = false;
  bool _settingsSaving = false;
  final _settingsSaveNotifier = SettingsSaveNotifier();
  final _logSearchFocus = FocusNode();

  double _rightPanelWidth = rightPanelDefaultWidth;
  double _logsPanelWidth = logsPanelDefaultWidth;
  double _previewPanelWidth = previewPanelDefaultWidth;
  bool _previewCollapsed = false;
  bool _layoutInitialized = false;

  @override
  void dispose() {
    _logSearchFocus.dispose();
    super.dispose();
  }

  void _initLayoutFromSettings(AppSettings settings) {
    _rightPanelWidth =
        clampRightPanelWidth(settings.rightPanelWidth.toDouble());
    _previewPanelWidth =
        clampPreviewPanelWidth(settings.previewPanelWidth.toDouble());
    _previewCollapsed = settings.previewCollapsed;
    _logsPanelWidth = clampLogsPanelWidth(
      settings.logsPanelWidth.toDouble(),
      totalWidth: MediaQuery.sizeOf(context).width,
      previewWidth: _previewPanelWidth,
      rightWidth: _rightPanelWidth,
      previewCollapsed: _previewCollapsed,
    );
    _layoutInitialized = true;
  }

  void _persistLayout() {
    ref.read(settingsProvider.notifier).updatePartial({
      'rightPanelWidth': _rightPanelWidth.round(),
      'logsPanelWidth': _logsPanelWidth.round(),
      'previewPanelWidth': _previewPanelWidth.round(),
      'previewCollapsed': _previewCollapsed,
    });
  }

  @override
  Widget build(BuildContext context) {
    // ⚡ Bolt: Prevent unnecessary AppShell rebuilds by selecting only healthWarningCount
    final healthWarnings = ref.watch(appProvider.select((a) => a.healthWarningCount)) ?? 0;
    final settings = ref.watch(settingsProvider).settings;
    final totalWidth = MediaQuery.sizeOf(context).width;

    if (ref.watch(settingsProvider).loaded && !_layoutInitialized) {
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
    ref.listen(settingsProvider.select((s) => s.settings.previewPanelWidth),
        (prev, next) {
      if (!_layoutInitialized) return;
      setState(() {
        _previewPanelWidth = clampPreviewPanelWidth(next.toDouble());
        _logsPanelWidth = clampLogsPanelWidth(
          _logsPanelWidth,
          totalWidth: totalWidth,
          previewWidth: _previewPanelWidth,
          rightWidth: _rightPanelWidth,
          previewCollapsed: _previewCollapsed,
        );
      });
    });
    ref.listen(settingsProvider.select((s) => s.settings.previewCollapsed),
        (prev, next) {
      if (!_layoutInitialized) return;
      setState(() => _previewCollapsed = next);
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
                  child: Padding(
                    padding: const EdgeInsets.all(_shellPadding),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final clampedLogs = clampLogsPanelWidth(
                          _logsPanelWidth,
                          totalWidth: width + (_shellPadding * 2),
                          previewWidth: _previewPanelWidth,
                          rightWidth: _rightPanelWidth,
                          previewCollapsed: _previewCollapsed,
                        );

                        return Row(
                          children: [
                            if (_previewCollapsed)
                              PatrolCard(
                                padding: EdgeInsets.zero,
                                child: SimulatorPreviewPanel(
                                  collapsed: true,
                                  onToggleCollapse: () {
                                    setState(() => _previewCollapsed = false);
                                    _persistLayout();
                                  },
                                ),
                              )
                            else
                              SizedBox(
                                width: _previewPanelWidth,
                                child: Stack(
                                  children: [
                                    PatrolCard(
                                      padding: EdgeInsets.zero,
                                      child: SimulatorPreviewPanel(
                                        collapsed: false,
                                        onToggleCollapse: () {
                                          setState(() => _previewCollapsed = true);
                                          _persistLayout();
                                        },
                                      ),
                                    ),
                                    PanelResizeHandle(
                                      edge: PanelResizeEdge.right,
                                      onDrag: (delta) {
                                        setState(() {
                                          _previewPanelWidth =
                                              clampPreviewPanelWidth(
                                            _previewPanelWidth + delta,
                                          );
                                          _logsPanelWidth = clampLogsPanelWidth(
                                            _logsPanelWidth,
                                            totalWidth:
                                                width + (_shellPadding * 2),
                                            previewWidth: _previewPanelWidth,
                                            rightWidth: _rightPanelWidth,
                                            previewCollapsed: _previewCollapsed,
                                          );
                                        });
                                      },
                                      onDragEnd: (_) => _persistLayout(),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(width: _panelGutter),
                            Expanded(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: clampedLogs,
                                ),
                                child: Stack(
                                  children: [
                                    PatrolCard(
                                      child: LogsPanel(
                                        searchFocusNode: _logSearchFocus,
                                      ),
                                    ),
                                    PanelResizeHandle(
                                      edge: PanelResizeEdge.right,
                                      onDrag: (delta) {
                                        setState(() {
                                          _rightPanelWidth =
                                              clampRightPanelWidth(
                                            _rightPanelWidth - delta,
                                          );
                                          _logsPanelWidth = clampLogsPanelWidth(
                                            _logsPanelWidth,
                                            totalWidth:
                                                width + (_shellPadding * 2),
                                            previewWidth: _previewPanelWidth,
                                            rightWidth: _rightPanelWidth,
                                            previewCollapsed: _previewCollapsed,
                                          );
                                        });
                                      },
                                      onDragEnd: (_) => _persistLayout(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: _panelGutter),
                            SizedBox(
                              width: _rightPanelWidth,
                              child: Stack(
                                children: [
                                  PanelResizeHandle(
                                    onDrag: (delta) {
                                      setState(() {
                                        _rightPanelWidth =
                                            clampRightPanelWidth(
                                          _rightPanelWidth - delta,
                                        );
                                      });
                                    },
                                    onDragEnd: (_) => _persistLayout(),
                                  ),
                                  PatrolCard(
                                    child: Column(
                                      children: [
                                        _RightPanelTabs(
                                          selected: _rightTab,
                                          healthWarnings: healthWarnings,
                                          onSelected: (tab) =>
                                              setState(() => _rightTab = tab),
                                        ),
                                        Expanded(
                                          child: switch (_rightTab) {
                                            RightPanelTab.tests => TestExplorer(
                                                onRefresh: () => ref
                                                    .read(appProvider.notifier)
                                                    .scanTests(),
                                              ),
                                            RightPanelTab.inspector =>
                                              const HierarchyInspector(),
                                            RightPanelTab.recordings =>
                                              const RecordingsPanel(),
                                            RightPanelTab.history =>
                                              const RunHistory(),
                                            RightPanelTab.health =>
                                              const EnvironmentHealth(),
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
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

  Widget _settingsModal(AppSettings settings) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
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
                        IconButton(
                          onPressed: _requestCloseSettings,
                          icon: const Icon(Icons.close, size: 18),
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

class _RightPanelTabs extends StatelessWidget {
  const _RightPanelTabs({
    required this.selected,
    required this.healthWarnings,
    required this.onSelected,
  });

  final RightPanelTab selected;
  final int healthWarnings;
  final ValueChanged<RightPanelTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PatrolColors.pebble)),
      ),
      child: Row(
        children: RightPanelTab.values.map((tab) {
          final isSelected = selected == tab;
          final label = switch (tab) {
            RightPanelTab.tests => 'Tests',
            RightPanelTab.inspector => 'Inspect',
            RightPanelTab.recordings => 'Record',
            RightPanelTab.history => 'History',
            RightPanelTab.health => healthWarnings > 0
                ? 'Health ($healthWarnings)'
                : 'Health',
          };
          final icon = switch (tab) {
            RightPanelTab.tests => Icons.refresh,
            RightPanelTab.inspector => Icons.ads_click_outlined,
            RightPanelTab.recordings => Icons.radio_button_checked_outlined,
            RightPanelTab.history => Icons.history,
            RightPanelTab.health => Icons.monitor_heart_outlined,
          };

          return Expanded(
            child: InkWell(
              onTap: () => onSelected(tab),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? PatrolColors.ink
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 10,
                      color: isSelected
                          ? PatrolColors.ink
                          : PatrolColors.steel,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: isSelected
                            ? PatrolColors.ink
                            : PatrolColors.steel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}