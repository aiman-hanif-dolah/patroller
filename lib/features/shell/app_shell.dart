import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/runner_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/collapsible_panel.dart';
import '../../widgets/panel_resize_handle.dart';
import '../../widgets/patrol_card.dart';
import '../../widgets/patrol_components.dart';
import '../../widgets/report_ready_dialog.dart';
import '../../widgets/snackbar_overlay.dart';
import '../agent/agent_workbench_panel.dart';
import '../devtools/devtools_panel.dart';
import '../health/environment_health.dart';
import '../history/run_history.dart';
import '../logs/logs_shell.dart';
import '../recordings/recordings_panel.dart';
import '../runner/run_toolbar.dart';
import '../settings/control_deck.dart';
import '../tests/test_explorer.dart';

enum WorkspacePanelTab { tests, recordings, agent, history, health, devtools }

const double _shellPadding = 12;
const double _panelGutter = 12;

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  WorkspacePanelTab _workspaceTab = WorkspacePanelTab.tests;
  final _logSearchFocus = FocusNode();

  late final ValueNotifier<double> _rightPanelWidth;
  late final ValueNotifier<double> _logsPanelWidth;
  bool _layoutInitialized = false;

  @override
  void initState() {
    super.initState();
    _rightPanelWidth = ValueNotifier(rightPanelDefaultWidth);
    _logsPanelWidth = ValueNotifier(logsPanelDefaultWidth);
  }

  @override
  void dispose() {
    _logSearchFocus.dispose();
    _rightPanelWidth.dispose();
    _logsPanelWidth.dispose();
    super.dispose();
  }

  void _initLayoutFromSettings(AppSettings settings) {
    _rightPanelWidth.value =
        clampRightPanelWidth(settings.rightPanelWidth.toDouble());
    _logsPanelWidth.value = clampLogsPanelWidth(
      settings.logsPanelWidth.toDouble(),
      totalWidth: MediaQuery.sizeOf(context).width,
      rightWidth: _rightPanelWidth.value,
    );
    _layoutInitialized = true;
  }

  void _persistLayout() {
    ref.read(settingsProvider.notifier).updatePartial({
      'rightPanelWidth': _rightPanelWidth.value.round(),
      'logsPanelWidth': _logsPanelWidth.value.round(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final app = ref.watch(appProvider);
    final settingsLoaded = ref.watch(settingsProvider.select((s) => s.loaded));
    final settings = ref.watch(settingsProvider.select((s) => s.settings));

    if (settingsLoaded && !_layoutInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _initLayoutFromSettings(settings));
        if (app.currentProject != null &&
            ref.read(runnerProvider).devices.isEmpty) {
          ref.read(runnerProvider.notifier).loadDevices();
        }
      });
    }

    ref.listen(settingsProvider.select((s) => s.settings.rightPanelWidth),
        (prev, next) {
      if (!_layoutInitialized) return;
      _rightPanelWidth.value = clampRightPanelWidth(next.toDouble());
    });
    ref.listen(settingsProvider.select((s) => s.settings.logsPanelWidth),
        (prev, next) {
      if (!_layoutInitialized) return;
      final viewportWidth = MediaQuery.sizeOf(context).width;
      _logsPanelWidth.value = clampLogsPanelWidth(
        next.toDouble(),
        totalWidth: viewportWidth,
        rightWidth: _rightPanelWidth.value,
      );
    });

    // Prompt user to open the HTML report when Test All / export finishes.
    ref.listen(runnerProvider.select((s) => s.reportPrompt), (prev, next) {
      if (next == null || next.id == prev?.id) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ReportReadyDialog.show(
          context,
          prompt: next,
          onDismiss: () {
            ref.read(runnerProvider.notifier).dismissReportPrompt();
          },
        );
      });
    });

    return SnackbarOverlay(
      child: Scaffold(
        backgroundColor: p.canvas,
        body: Column(
          children: [
            RunToolbar(
              onOpenProject: () => ref.read(appProvider.notifier).openProject(),
              onRefreshTests: () => ref.read(appProvider.notifier).scanTests(),
            ),
            // Selection / Test All status lives on RunToolbar (no second strip).
            // Control Deck lives under the Logs column (not full-width), so
            // Workspace keeps full height on the top-right.
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

                      return ValueListenableBuilder<double>(
                        valueListenable: _logsPanelWidth,
                        builder: (context, logsWidth, _) {
                          return ValueListenableBuilder<double>(
                            valueListenable: _rightPanelWidth,
                            builder: (context, rightWidth, _) {
                              final clampedLogs = clampLogsPanelWidth(
                                logsWidth,
                                totalWidth: viewportWidth,
                                rightWidth: rightWidth,
                              );

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildLogsColumn(
                                    clampedLogs,
                                    viewportWidth,
                                  ),
                                  const SizedBox(width: _panelGutter),
                                  Expanded(
                                    child: _buildWorkspaceColumn(
                                      healthState: ref.watch(healthProvider),
                                      app: app,
                                      rightWidth: rightWidth,
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsColumn(double clampedLogs, double viewportWidth) {
    return SizedBox(
      width: clampedLogs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                PatrolCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      const CollapsiblePanelHeader(title: 'Logs'),
                      Expanded(
                        child: LogsShell(searchFocusNode: _logSearchFocus),
                      ),
                    ],
                  ),
                ),
                PanelResizeHandle(
                  edge: PanelResizeEdge.right,
                  onDrag: (delta) {
                    _logsPanelWidth.value = clampLogsPanelWidth(
                      _logsPanelWidth.value + delta,
                      totalWidth: viewportWidth,
                      rightWidth: _rightPanelWidth.value,
                    );
                  },
                  onDragEnd: (_) => _persistLayout(),
                ),
              ],
            ),
          ),
          const SizedBox(height: _panelGutter),
          const ControlDeck(),
        ],
      ),
    );
  }

  Widget _buildWorkspaceColumn({
    required HealthState healthState,
    required AppState app,
    required double rightWidth,
  }) {
    final healthWarnings =
        healthState.warningCount ?? app.healthWarningCount ?? 0;

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: rightWidth),
      child: Stack(
        children: [
          PanelResizeHandle(
            onDrag: (delta) {
              _rightPanelWidth.value = clampRightPanelWidth(
                _rightPanelWidth.value - delta,
              );
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
                ),
                Expanded(
                  child: switch (_workspaceTab) {
                    WorkspacePanelTab.tests => TestExplorer(
                        onRefresh: () =>
                            ref.read(appProvider.notifier).scanTests(),
                      ),
                    WorkspacePanelTab.recordings => const RecordingsPanel(),
                    WorkspacePanelTab.agent => const AgentWorkbenchPanel(),
                    WorkspacePanelTab.history => const RunHistory(),
                    WorkspacePanelTab.health => const EnvironmentHealth(),
                    WorkspacePanelTab.devtools => const DevToolsPanel(),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspacePanelTabs extends StatelessWidget {
  const _WorkspacePanelTabs({
    required this.selected,
    required this.healthWarnings,
    required this.onSelected,
  });

  final WorkspacePanelTab selected;
  final int healthWarnings;
  final ValueChanged<WorkspacePanelTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        border: Border(
          bottom: BorderSide(color: p.border),
        ),
      ),
      child: Padding(
        // Keep first/last tabs clear of the ~4px panel resize hit strip.
        padding: const EdgeInsets.only(left: 6),
        child: Row(
          children: [
            ...WorkspacePanelTab.values.map((tab) {
              final isSelected = selected == tab;
              final label = switch (tab) {
                WorkspacePanelTab.tests => 'Tests',
                WorkspacePanelTab.recordings => 'Record',
                WorkspacePanelTab.agent => 'Agent',
                WorkspacePanelTab.history => 'History',
                WorkspacePanelTab.health => 'Health',
                WorkspacePanelTab.devtools => 'DevTools',
              };
              final badge = tab == WorkspacePanelTab.health && healthWarnings > 0
                  ? 'HEALTH ($healthWarnings)'
                  : null;
              final icon = switch (tab) {
                WorkspacePanelTab.tests => Icons.science_outlined,
                WorkspacePanelTab.recordings =>
                  Icons.fiber_manual_record_outlined,
                WorkspacePanelTab.agent => Icons.smart_toy_outlined,
                WorkspacePanelTab.history => Icons.history_rounded,
                WorkspacePanelTab.health => Icons.monitor_heart_outlined,
                WorkspacePanelTab.devtools => Icons.extension_outlined,
              };
              final tabColor = switch (tab) {
                WorkspacePanelTab.tests => PatrolColors.sky400,
                WorkspacePanelTab.recordings => PatrolColors.amber,
                WorkspacePanelTab.agent => PatrolColors.violet400,
                WorkspacePanelTab.history => PatrolColors.violet400,
                WorkspacePanelTab.health => PatrolColors.orange400,
                WorkspacePanelTab.devtools => PatrolColors.sky400,
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
          ],
        ),
      ),
    );
  }
}
