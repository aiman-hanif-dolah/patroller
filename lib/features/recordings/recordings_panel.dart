import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/recording_enrichment.dart';
import '../../domain/recording_import_validation.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/log_provider.dart';
import '../../providers/recording_provider.dart';
import '../../domain/simulator_driver_readiness.dart';
import '../../providers/health_provider.dart';
import '../../providers/simulator_driver_readiness_provider.dart';
import '../../providers/runner_provider.dart';
import '../../widgets/accessible_icon_button.dart';
import '../devices/device_picker.dart';
import 'flow_editor.dart';

class RecordingsPanel extends ConsumerStatefulWidget {
  const RecordingsPanel({super.key});

  @override
  ConsumerState<RecordingsPanel> createState() => _RecordingsPanelState();
}

class _RecordingsPanelState extends ConsumerState<RecordingsPanel> {
  bool _showDeviceList = false;
  Recording? _selectedRecording;
  final _recordingNameController = TextEditingController();
  RecordingEnvironmentProfile _environmentProfile =
      RecordingEnvironmentProfile.live;
  final _importController = TextEditingController();
  String? _importError;
  bool _isSaving = false;
  bool _isImporting = false;
  String? _savedTestPath;
  String? _renameValue;

  @override
  void dispose() {
    _recordingNameController.dispose();
    _importController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final project = ref.watch(appProvider).currentProject;
    final device = ref.watch(runnerProvider).selectedDevice;
    final recordingState = ref.watch(recordingProvider);
    final readiness = ref.watch(simulatorDriverReadinessProvider);

    ref.listen(appProvider.select((s) => s.currentProject?.projectPath), (prev, next) {
      if (prev != next && next != null) {
        ref.read(recordingProvider.notifier).loadRecordings(next);
      }
      if (prev != next) {
        setState(() {
          _selectedRecording = null;
          _savedTestPath = null;
        });
        ref.read(recordingProvider.notifier).resetForProjectSwitch();
      }
    });

    if (project != null && recordingState.recordings.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(recordingProvider.notifier).loadRecordings(project.projectPath);
      });
    }

    if (project == null) {
      final p = PatrolPalette.of(context);
      return Center(
        child: Text(
          'Open a project to record actions',
          style: TextStyle(fontSize: 14, color: p.textMuted),
        ),
      );
    }

    if (recordingState.isRecording == false && device == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(runnerProvider.notifier).refreshDevices();
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPrepareSection(project, device, recordingState, readiness),
        Divider(height: 1, color: p.border),
        Expanded(child: _buildSavedList(recordingState)),
        if (_selectedRecording != null)
          _buildSelectedSection(project, device, recordingState, _selectedRecording!),
      ],
    );
  }

  Widget _buildPrepareSection(
    ProjectMetadata project,
    DeviceInfo? device,
    RecordingState recordingState,
    SimulatorDriverReadiness readiness,
  ) {
    final p = PatrolPalette.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _SectionHeading('Prepare'),
              const Spacer(),
              if (recordingState.isRecording)
                const Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: PatrolColors.red400),
                    SizedBox(width: 4),
                    Text('Recording', style: TextStyle(fontSize: 11, color: PatrolColors.red400)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          _SectionHeading(device?.name ?? 'Simulator'),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() => _showDeviceList = !_showDeviceList),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: p.surfaceMuted,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: p.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      device == null
                          ? 'Select simulator'
                          : device.state == DeviceState.booted
                              ? device.name
                              : '${device.name} (boot required)',
                      style: TextStyle(fontSize: 14, color: p.text),
                    ),
                  ),
                  Icon(
                    _showDeviceList ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: p.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_showDeviceList) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.border),
              ),
              child: DevicePickerList(
                onSelected: () => setState(() => _showDeviceList = false),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _recordingNameController,
            enabled: !_isSaving && !_isImporting,
            style: TextStyle(fontSize: 13, color: p.text),
            decoration: InputDecoration(
              hintText: 'Recording name',
              hintStyle: TextStyle(fontSize: 13, color: p.textMuted),
              prefixIcon: Icon(Icons.edit_outlined, size: 18, color: p.textMuted),
              isDense: true,
              filled: true,
              fillColor: p.surfaceMuted,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                borderSide: BorderSide(color: PatrolColors.amber.withValues(alpha: 0.6)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: RecordingEnvironmentProfile.values.map((profile) {
              final p = PatrolPalette.of(context);
              final selected = _environmentProfile == profile;
              final label = profile.toJson();
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: (_isSaving || _isImporting)
                        ? null
                        : () => setState(() => _environmentProfile = profile),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? p.text : p.surfaceMuted,
                        borderRadius: BorderRadius.circular(999),
                        border: selected
                            ? null
                            : Border.all(color: p.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? p.surface
                              : p.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            recordingInstructionCopy(readiness),
            style: TextStyle(fontSize: 11, color: p.textMuted),
          ),
          if (readiness.showRepairAction) ...[
            const SizedBox(height: 8),
            Text(
              readiness.fixInstruction,
              style: const TextStyle(fontSize: 10, color: PatrolColors.ember),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _repairDriver(project),
                icon: const Icon(Icons.build_circle_outlined, size: 14),
                label: const Text('Repair driver'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const _SectionHeading('Record'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: recordingState.isRecording
                      ? (_isSaving ? null : () => _saveActive(project, device))
                      : readiness.allowExternalFallback
                          ? () =>
                              ref.read(recordingProvider.notifier).startRecording()
                          : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: recordingState.isRecording
                          ? PatrolColors.ember
                          : PatrolColors.red400,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          recordingState.isRecording
                              ? Icons.save
                              : Icons.fiber_manual_record,
                          size: 16,
                          color: p.onAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          recordingState.isRecording
                              ? (_isSaving ? 'Saving...' : 'Save')
                              : 'Record',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: p.onAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: recordingState.isRecording
                      ? () => ref.read(recordingProvider.notifier).cancelRecording()
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: p.surfaceMuted,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: p.border,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          recordingState.isRecording ? Icons.close : Icons.stop,
                          size: 16,
                          color: p.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          recordingState.isRecording ? 'Cancel' : 'Stop',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: p.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (recordingState.isRecording) ...[
            const SizedBox(height: 8),
            Text(
              recordingActiveCopy(
                readiness: readiness,
                actionCount: recordingState.activeActions.length,
              ),
              style: TextStyle(fontSize: 11, color: p.textMuted),
            ),
            if (recordingState.activeActions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 112),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: p.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.border),
                ),
                child: SingleChildScrollView(
                  child: _ActionTimeline(actions: recordingState.activeActions),
                ),
              ),
            ],
          ],
          if (recordingState.error != null) ...[
            const SizedBox(height: 8),
            Text(
              recordingState.error!,
              style: const TextStyle(fontSize: 11, color: PatrolColors.red400),
            ),
          ],
          if (recordingState.replayResult != null) ...[
            const SizedBox(height: 8),
            Text(
              'Replay ${recordingState.replayResult!.status}: ${recordingState.replayResult!.actionCount} actions · ${recordingState.replayResult!.logs.length} logs',
              style: TextStyle(
                fontSize: 11,
                color: recordingState.replayResult!.status == 'passed'
                    ? PatrolColors.psPassed
                    : PatrolColors.red400,
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Use Material with an explicit surface so ExpansionTile's ListTile
          // has a Material ancestor below any colored panel DecoratedBox.
          Material(
            color: p.surface,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              backgroundColor: Colors.transparent,
              collapsedBackgroundColor: Colors.transparent,
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                'Import JSON',
                style: TextStyle(fontSize: 11, color: p.textMuted),
              ),
              children: [
                TextField(
                  controller: _importController,
                  enabled: !_isImporting,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'Paste exported recording JSON',
                    errorText: _importError,
                  ),
                  onChanged: (_) {
                    if (_importError != null) {
                      setState(() => _importError = null);
                    }
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed:
                      (_importController.text.trim().isNotEmpty && !_isImporting)
                          ? () => _importFromJson(project.projectPath)
                          : null,
                  icon: const Icon(Icons.upload, size: 14),
                  label: Text(_isImporting ? 'Importing...' : 'Import'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedList(RecordingState recordingState) {
    final p = PatrolPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: _SectionHeading('Saved Recordings'),
        ),
        Expanded(
          child: recordingState.recordings.isEmpty
              ? Center(
                  child: Text(
                    'No recordings saved',
                    style: TextStyle(fontSize: 12, color: p.textMuted),
                  ),
                )
              : ListView.builder(
                  itemCount: recordingState.recordings.length,
                  itemBuilder: (context, index) {
                    final p = PatrolPalette.of(context);
                    final recording = recordingState.recordings[index];
                    final selected = _selectedRecording?.id == recording.id;
                    return Material(
                      color: selected
                          ? p.surfaceMuted
                          : Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() {
                          _selectedRecording =
                              selected ? null : recording;
                          _savedTestPath = null;
                          _renameValue = null;
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                recording.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: p.text,
                                ),
                              ),
                              Text(
                                '${recording.actionCount} actions · ${recording.environmentProfile.toJson()} · ${_formatDuration(recording.durationMs)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: p.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSelectedSection(
    ProjectMetadata project,
    DeviceInfo? device,
    RecordingState recordingState,
    Recording recording,
  ) {
    final p = PatrolPalette.of(context);
    final latestReplay =
        recording.replayResults.isNotEmpty ? recording.replayResults.first : null;
    final warnings = _collectWarnings(recording.actions);

    return Container(
      constraints: const BoxConstraints(maxHeight: 560),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeading('Selected Recording'),
            const SizedBox(height: 8),
            if (_renameValue == null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      recording.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: p.text,
                      ),
                    ),
                  ),
                  AccessibleIconButton(
                    icon: Icons.edit,
                    label: 'Rename recording ${recording.name}',
                    onPressed: () => setState(() => _renameValue = recording.name),
                    size: 14,
                    color: p.textMuted,
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      controller: TextEditingController(text: _renameValue),
                      onChanged: (v) => _renameValue = v,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _submitRename(project.projectPath, recording.id),
                    child: const Text('Save'),
                  ),
                ],
              ),
            Text(
              'Device: ${recording.deviceName ?? 'Any selected simulator'} · '
              '${recording.actionCount} steps · ${recording.environmentProfile.toJson()}',
              style: TextStyle(fontSize: 10, color: p.textMuted),
            ),
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PatrolColors.ember.withValues(alpha: 0.1),
                  border: Border.all(color: PatrolColors.ember.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: warnings
                      .map(
                        (w) => Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber, size: 12, color: PatrolColors.ember),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                w,
                                style: const TextStyle(fontSize: 10, color: PatrolColors.ember),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            const SizedBox(height: 10),
            FlowEditorView(
              key: ValueKey('flow-${recording.id}'),
              recording: recording,
              isReplaying: recordingState.isReplaying,
              canReplay: device != null && !recordingState.isReplaying,
              onActionsChanged: (actions) async {
                final updated = await ref
                    .read(recordingProvider.notifier)
                    .updateRecordingActions(
                      recording.id,
                      project.projectPath,
                      actions,
                    );
                if (updated != null && mounted) {
                  setState(() => _selectedRecording = updated);
                }
              },
              onSaveTest: () => _saveTest(project.projectPath, recording.id),
              onSaveAndDevelop: () => _saveTestAndRun(
                    project.projectPath,
                    recording.id,
                    develop: true,
                  ),
              onSaveAndTest: () => _saveTestAndRun(
                    project.projectPath,
                    recording.id,
                    develop: false,
                  ),
              onReplay: () => ref
                  .read(recordingProvider.notifier)
                  .replayRecording(recording, device),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _copyButton('Patrol Test', () => _copyExport(recording, project.projectPath, 'patrolTest')),
                _copyButton('Flow', () => _copyExport(recording, project.projectPath, 'flow')),
                _copyButton('JSON', () => _copyExport(recording, project.projectPath, 'json')),
                _copyButton('Logs', () => _copyExport(recording, project.projectPath, 'logs')),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _deleteRecording(project.projectPath, recording.id),
              icon: const Icon(Icons.delete, size: 14, color: PatrolColors.red400),
              label: const Text('Delete', style: TextStyle(color: PatrolColors.red400)),
            ),
            if (_savedTestPath != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Saved: $_savedTestPath',
                  style: const TextStyle(fontSize: 10, color: PatrolColors.psPassed),
                ),
              ),
            if (latestReplay != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: p.fill,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Latest run: ${latestReplay.status} · ${latestReplay.startedAt}',
                      style: TextStyle(
                        fontSize: 10,
                        color: latestReplay.status == 'passed'
                            ? PatrolColors.psPassed
                            : PatrolColors.red400,
                      ),
                    ),
                    if (latestReplay.error != null)
                      Text(
                        latestReplay.error!,
                        style: const TextStyle(fontSize: 10, color: PatrolColors.red400),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _copyButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        textStyle: const TextStyle(fontSize: 10),
      ),
      child: Text(label),
    );
  }

  Future<void> _repairDriver(ProjectMetadata project) async {
    final error =
        await ref.read(healthProvider.notifier).repairDriver(project.projectPath);
    if (error != null) {
      ref.read(runnerProvider.notifier).showSnackbar('Repair failed: $error');
    } else {
      ref.read(runnerProvider.notifier).showSnackbar('Simulator driver repaired');
    }
  }

  Future<void> _saveActive(ProjectMetadata project, DeviceInfo? device) async {
    setState(() => _isSaving = true);
    try {
      final recording = await ref.read(recordingProvider.notifier).saveRecording(
            projectPath: project.projectPath,
            selectedDevice: device,
            logs: ref.read(logProvider).logs,
            name: _recordingNameController.text,
            environmentProfile: _environmentProfile,
          );
      if (recording != null) {
        setState(() {
          _selectedRecording = recording;
          _recordingNameController.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _importFromJson(String projectPath) async {
    final validation = validateRecordingImportText(_importController.text);
    if (!validation.ok) {
      setState(() => _importError = validation.message);
      return;
    }
    setState(() {
      _importError = null;
      _isImporting = true;
    });
    try {
      final recording = await ref
          .read(recordingProvider.notifier)
          .importRecording(projectPath, _importController.text);
      if (recording != null) {
        setState(() {
          _selectedRecording = recording;
          _importController.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _submitRename(String projectPath, String recordingId) async {
    final value = _renameValue?.trim();
    if (value == null || value.isEmpty) {
      setState(() => _renameValue = null);
      return;
    }
    final updated = await ref
        .read(recordingProvider.notifier)
        .renameRecording(recordingId, projectPath, value);
    if (updated != null) {
      setState(() {
        _selectedRecording = updated;
        _renameValue = null;
      });
      ref.read(runnerProvider.notifier).showSnackbar('Recording renamed');
    }
  }

  Future<void> _saveTest(String projectPath, String recordingId) async {
    await _saveTestAndSelect(projectPath, recordingId);
  }

  Future<TestFile?> _saveTestAndSelect(
    String projectPath,
    String recordingId,
  ) async {
    final testFile = await ref
        .read(recordingProvider.notifier)
        .saveTestFile(recordingId, projectPath);
    if (testFile == null) return null;
    setState(() => _savedTestPath = testFile.relativePath);
    await ref.read(appProvider.notifier).scanTests();
    final generated = ref
        .read(appProvider)
        .testFiles
        .where((f) => f.relativePath == testFile.relativePath)
        .firstOrNull;
    if (generated != null) {
      ref.read(appProvider.notifier).setSelectedFile(generated);
    }
    return generated;
  }

  Future<void> _saveTestAndRun(
    String projectPath,
    String recordingId, {
    required bool develop,
  }) async {
    final generated = await _saveTestAndSelect(projectPath, recordingId);
    if (generated == null) return;
    if (develop) {
      await ref.read(runnerProvider.notifier).develop();
    } else {
      await ref.read(runnerProvider.notifier).runSelected();
    }
  }

  Future<void> _copyExport(
    Recording recording,
    String projectPath,
    String kind,
  ) async {
    final exported = await ref
        .read(recordingProvider.notifier)
        .exportRecording(recording.id, projectPath);
    if (exported == null) return;
    final text = switch (kind) {
      'flow' => exported.flow,
      'json' => exported.json,
      'logs' => exported.logs,
      'replayLogs' => exported.replayLogs,
      _ => exported.patrolTest,
    };
    await Clipboard.setData(ClipboardData(text: text));
    ref.read(runnerProvider.notifier).showSnackbar('Recording export copied');
  }

  Future<void> _deleteRecording(String projectPath, String recordingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete recording?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(recordingProvider.notifier).deleteRecording(recordingId, projectPath);
    setState(() => _selectedRecording = null);
  }

  List<String> _collectWarnings(List<RecordingAction> actions) {
    final seen = <ActionWarningKind>{};
    final messages = <String>[];
    for (final action in actions) {
      for (final warning in deriveActionWarnings(action)) {
        if (seen.add(warning)) {
          messages.add(actionWarningLabels[warning]!);
        }
      }
    }
    return messages;
  }

  String _formatDuration(int ms) {
    if (ms < 1000) return '${ms}ms';
    return '${(ms / 1000).toStringAsFixed(1)}s';
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: p.textMuted,
      ),
    );
  }
}

class _ActionTimeline extends StatelessWidget {
  const _ActionTimeline({required this.actions});

  final List<RecordingAction> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          _ActionLine(index: i + 1, action: actions[i]),
          if (i < actions.length - 1) const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class _ActionLine extends StatelessWidget {
  const _ActionLine({required this.index, required this.action});

  final int index;
  final RecordingAction action;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final warnings = deriveActionWarnings(action);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$index. ${_actionTitle(action)}',
                style: TextStyle(fontSize: 10, color: p.text),
              ),
              Text(
                'Delay ${action.delayMs}ms',
                style: TextStyle(fontSize: 9, color: p.textMuted),
              ),
            ],
          ),
        ),
        if (warnings.isNotEmpty)
          const Icon(Icons.warning_amber, size: 10, color: PatrolColors.ember),
      ],
    );
  }

  String _actionTitle(RecordingAction action) {
    switch (action.type) {
      case RecordingActionType.tap:
        return action.targetLabel != null
            ? 'Tap "${action.targetLabel}"'
            : 'Tap';
      case RecordingActionType.longpress:
        return action.targetLabel != null
            ? 'Long press "${action.targetLabel}"'
            : 'Long press';
      case RecordingActionType.swipe:
        final dx = (action.toX ?? action.x ?? 0) - (action.x ?? 0);
        final dy = (action.toY ?? action.y ?? 0) - (action.y ?? 0);
        if (dy.abs() >= dx.abs()) {
          return dy < 0 ? 'Scroll down' : 'Scroll up';
        }
        return dx < 0 ? 'Swipe left' : 'Swipe right';
      case RecordingActionType.text:
        return 'Type "${action.text ?? ''}"';
      case RecordingActionType.key:
        return 'Key ${action.key ?? ''}';
      case RecordingActionType.assertVisible:
        final label = action.targetLabel ?? action.text;
        return label != null && label.isNotEmpty
            ? 'Assert "$label" visible'
            : 'Assert visible';
    }
  }
}