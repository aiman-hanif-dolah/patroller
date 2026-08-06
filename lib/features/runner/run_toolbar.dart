import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/runner_helpers.dart';
import '../../models/enums.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/runner_provider.dart';
import '../../providers/simulator_driver_readiness_provider.dart';
import '../../providers/test_run_state_provider.dart';
import '../../widgets/accessible_icon_button.dart';
import '../../widgets/patrol_components.dart';
import '../../widgets/status_badge.dart';
import '../devices/device_selector_button.dart';
import '../settings/user_credentials_dialog.dart';
import '../../services/user_credentials_store.dart';

class RunToolbar extends ConsumerStatefulWidget {
  const RunToolbar({
    super.key,
    required this.onOpenProject,
    required this.onRefreshTests,
  });

  final VoidCallback onOpenProject;
  final VoidCallback onRefreshTests;

  @override
  ConsumerState<RunToolbar> createState() => _RunToolbarState();
}

class _RunToolbarState extends ConsumerState<RunToolbar> {
  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final project = ref.watch(appProvider.select((s) => s.currentProject));
    final selectedFile = ref.watch(appProvider.select((s) => s.selectedFile));
    final flowFilter = ref.watch(appProvider.select((s) => s.flowFilter));
    final testFiles = ref.watch(appProvider.select((s) => s.testFiles));
    final hasTestFiles = testFiles.isNotEmpty;

    final isRunning = ref.watch(runnerProvider.select((s) => s.isRunning));
    final currentRun = ref.watch(runnerProvider.select((s) => s.currentRun));
    final selectedDevice =
        ref.watch(runnerProvider.select((s) => s.selectedDevice));
    final runAllContext =
        ref.watch(runnerProvider.select((s) => s.runAllContext));
    final queueStatus = ref.watch(runnerProvider.select((s) => s.queueStatus));
    final stopFailure = ref.watch(runnerProvider.select((s) => s.stopFailure));
    final health = ref.watch(healthProvider);
    final readiness = ref.watch(simulatorDriverReadinessProvider);
    final activeRunFile = ref.watch(activeRunFileProvider);

    final lifecycle = resolveLifecycle(currentRun);
    final sessionBusy = isSessionBusy(isRunning, currentRun);

    final isTestRun = isRunning &&
        currentRun?.runMode.name == 'test' &&
        runAllContext == null;
    final isCoverageRun = isRunning &&
        currentRun?.runMode == RunMode.coverage &&
        runAllContext == null;
    final isQueueRun = isRunning && runAllContext != null;
    final isHotRun = isRunning && currentRun?.runMode == RunMode.develop;
    final isHotSuite =
        isRunning && currentRun?.runMode == RunMode.developSuite;
    final isHotSession = isHotRun || isHotSuite;
    final hotRestartBlock = hotRestartDisabledReason(
      isRunning: isRunning,
      currentRun: currentRun,
    );

    final runDisabled = getRunDisabledReason(
      hasProject: project != null,
      hasSelectedFile: selectedFile != null,
      isRunning: isRunning,
      selectedDevice: selectedDevice,
      currentRun: currentRun,
    );
    final queueDisabled = getQueueRunDisabledReason(
      hasProject: project != null,
      hasTestFiles: hasTestFiles,
      isRunning: isRunning,
      selectedDevice: selectedDevice,
      currentRun: currentRun,
    );

    final queueProgress = queueStatus != null &&
            queueStatus.status == QueueStatus.running
        ? '${queueStatus.passedCount + queueStatus.failedCount + queueStatus.cancelledCount + queueStatus.skippedCount}/${queueStatus.total} · ${queueStatus.passedCount} passed · ${queueStatus.failedCount} failed · ${queueStatus.skippedCount} skipped'
        : null;

    final driverIssue = readiness.showRepairAction;
    final healthLabel = health.state == HealthCheckState.current &&
            driverIssue &&
            (health.warningCount ?? 0) == 0
        ? 'Driver issue'
        : formatHealthStripLabel(health);
    final healthWarn = health.state == HealthCheckState.failed ||
        driverIssue ||
        (health.state == HealthCheckState.current &&
            (health.warningCount ?? 0) > 0) ||
        health.state == HealthCheckState.stale;

    // Test All badge reflects flow scope (not checkbox multi-select).
    final runningFileLabel = isRunning && activeRunFile != null
        ? middleTruncate(activeRunFile.fileName, 28)
        : null;
    final testAllQueue = filesForRunAll(testFiles, flowFilter);
    final testAllBadge = !isRunning && hasTestFiles
        ? describeTestAllQueueBadge(
            flowFilter: flowFilter,
            queueFileCount: testAllQueue.length,
          )
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(
          bottom: BorderSide(color: p.border),
        ),
      ),
      child: Row(
        children: [
          // Brand cluster - fixed width, project name ellipsizes.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PatrolBrandMark(size: 30),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      project?.projectName ?? 'Patroller',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: p.text,
                      ),
                    ),
                    Text(
                      project != null
                          ? 'Patrol test runner'
                          : 'Open a project to begin',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: p.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              AccessibleIconButton(
                icon: Icons.folder_open_rounded,
                label: 'Open project',
                size: 14,
                onPressed: widget.onOpenProject,
              ),
            ],
          ),
          // Action cluster scrolls horizontally when the window is narrow.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _divider(),
                  PatrolStatusDot(
                    color: sessionBusy
                        ? PatrolColors.ember
                        : selectedDevice?.state == DeviceState.booted
                            ? PatrolColors.psPassed
                            : PatrolColors.amber,
                    pulse: sessionBusy,
                  ),
                  const SizedBox(width: 8),
                  const DeviceSelectorButton(),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: kIosSimulatorRunTargetHint,
                    child: Text(
                      'iOS Simulator',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: p.textMuted,
                      ),
                    ),
                  ),
                  _divider(),
                  const _CredentialSelector(),
                  _divider(),
                  _ActionButton(
                    label: 'Test',
                    icon: Icons.play_arrow_rounded,
                    active: isTestRun,
                    enabled: runDisabled == null,
                    tooltip: runDisabled ??
                        testButtonTooltip(
                          willBootSimulator:
                              selectedDevice?.state != DeviceState.booted,
                        ),
                    activeColor: PatrolColors.psPassed,
                    onPressed: () =>
                        ref.read(runnerProvider.notifier).runSelected(),
                  ),
                  const SizedBox(width: 6),
                  _ActionButton(
                    label: 'Coverage',
                    icon: Icons.pie_chart_outline_rounded,
                    active: isCoverageRun,
                    enabled: runDisabled == null,
                    tooltip: runDisabled ??
                        'Run patrol test with code coverage enabled (--coverage).',
                    activeColor: PatrolColors.emerald,
                    onPressed: () =>
                        ref.read(runnerProvider.notifier).runCoverage(),
                  ),
                  const SizedBox(width: 6),
                  _ActionButton(
                    label: 'Test All',
                    icon: Icons.format_list_numbered_rounded,
                    active: isQueueRun,
                    enabled: queueDisabled == null,
                    tooltip: queueDisabled ?? testAllButtonTooltip(flowFilter),
                    activeColor: PatrolColors.sky400,
                    onPressed: () => ref.read(runnerProvider.notifier).runAll(),
                  ),
                  const SizedBox(width: 6),
                  _ActionButton(
                    label: 'Develop',
                    icon: Icons.science_outlined,
                    active: isHotRun,
                    enabled: runDisabled == null,
                    tooltip: runDisabled ??
                        'Start patrol develop for the selected file.',
                    activeColor: PatrolColors.violet500,
                    onPressed: () =>
                        ref.read(runnerProvider.notifier).develop(),
                  ),
                  const SizedBox(width: 6),
                  _ActionButton(
                    label: 'Develop All',
                    icon: Icons.layers_outlined,
                    active: isHotSuite,
                    enabled: queueDisabled == null,
                    tooltip: queueDisabled ?? developAllButtonTooltip(flowFilter),
                    activeColor: PatrolColors.fuchsia500,
                    onPressed: () =>
                        ref.read(runnerProvider.notifier).developSuite(),
                  ),
                  if (isHotSession) ...[
                    const SizedBox(width: 6),
                    _ActionButton(
                      label: 'Restart',
                      icon: Icons.refresh_rounded,
                      active: hotRestartBlock == null,
                      enabled: hotRestartBlock == null,
                      tooltip: hotRestartBlock ??
                          'Hot restart active develop session (or switch to newly selected file).',
                      activeColor: PatrolColors.amberBright,
                      onPressed: () =>
                          ref.read(runnerProvider.notifier).hotRestart(),
                    ),
                  ],
                  _divider(),
                  _ActionButton(
                    label: lifecycle == RunLifecycle.stopping
                        ? 'Stopping...'
                        : 'Stop',
                    icon: Icons.stop_rounded,
                    active: lifecycle == RunLifecycle.stopping,
                    enabled: sessionBusy || stopFailure != null,
                    tooltip: sessionBusy
                        ? 'Stop the active test or develop session.'
                        : 'Nothing is running.',
                    activeColor: PatrolColors.red400,
                    onPressed: () => ref.read(runnerProvider.notifier).stop(),
                  ),
                  if (runningFileLabel != null) ...[
                    const SizedBox(width: 8),
                    WorkflowStatusBadge(
                      label: 'Running file',
                      value: runningFileLabel,
                      icon: Icons.description_outlined,
                      accent: PatrolColors.amber,
                    ),
                  ],
                  if (testAllBadge != null) ...[
                    const SizedBox(width: 8),
                    WorkflowStatusBadge(
                      label: testAllBadge.label,
                      value: testAllBadge.value,
                      icon: Icons.checklist_rounded,
                      accent: PatrolColors.sky400,
                    ),
                  ],
                  const SizedBox(width: 8),
                  WorkflowStatusBadge(
                    label: 'Health',
                    value: healthLabel,
                    warn: healthWarn,
                    icon: Icons.monitor_heart_outlined,
                    accent: PatrolColors.orange400,
                  ),
                  if (queueProgress != null) ...[
                    const SizedBox(width: 8),
                    PatrolMetaChip(
                      label: queueProgress,
                      icon: Icons.sync,
                      color: PatrolColors.sky400,
                      accent: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    final p = PatrolPalette.of(context);
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: p.border,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.enabled,
    required this.tooltip,
    required this.activeColor,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool active;
  final bool enabled;
  final String tooltip;
  final Color activeColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    // Always solid purpose fill (Restart-style); dark fg on light accents,
    // snow/white on darker fills (e.g. violet Develop) for contrast.
    final bg = activeColor;
    final fg =
        activeColor.computeLuminance() < 0.3 ? p.inverse : p.onAccent;
    final border = active
        ? Color.lerp(activeColor, PatrolColors.obsidian, 0.28)!
        : Colors.transparent;

    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label. $tooltip',
      child: Tooltip(
        message: tooltip,
        child: Opacity(
          opacity: enabled ? 1 : 0.38,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(PatrolRadius.pill),
            elevation: active ? 2 : 0,
            shadowColor: activeColor.withValues(alpha: 0.45),
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(PatrolRadius.pill),
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(PatrolRadius.pill),
                  border: Border.all(width: active ? 1.5 : 1, color: border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: fg),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CredentialSelector extends ConsumerWidget {
  const _CredentialSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = PatrolPalette.of(context);
    final credentials = ref.watch(userCredentialsProvider);
    final selected = ref.watch(userCredentialsProvider.notifier).selectedCredential;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.person_pin_rounded, size: 16, color: Colors.blueAccent),
        const SizedBox(width: 6),
        DropdownButton<String>(
          value: selected?.id,
          hint: Text('Select User Profile', style: TextStyle(fontSize: 12, color: p.textMuted)),
          underline: const SizedBox.shrink(),
          dropdownColor: p.surface,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: p.text,
          ),
          items: credentials.map((cred) {
            return DropdownMenuItem<String>(
              value: cred.id,
              child: Text(
                '${cred.name} (${cred.env.label} · ${cred.userMode.label})',
              ),
            );
          }).toList(),
          onChanged: (id) {
            if (id != null) {
              final found = credentials.firstWhere((c) => c.id == id);
              ref.read(userCredentialsProvider.notifier).selectCredential(found);
            }
          },
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.tune_rounded, size: 16),
          tooltip: 'Manage Credentials (TOON)',
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => const UserCredentialsDialog(),
            );
          },
        ),
      ],
    );
  }
}
