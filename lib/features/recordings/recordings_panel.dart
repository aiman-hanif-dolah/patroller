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
import '../../providers/preview_provider.dart';
import '../../providers/runner_provider.dart';

class RecordingsPanel extends ConsumerStatefulWidget {
  const RecordingsPanel({super.key});

  @override
  ConsumerState<RecordingsPanel> createState() => _RecordingsPanelState();
}

class _RecordingsPanelState extends ConsumerState<RecordingsPanel> {
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
  String? _codePreview;
  bool _loadingCodePreview = false;

  @override
  void dispose() {
    _recordingNameController.dispose();
    _importController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(appProvider).currentProject;
    final device = ref.watch(runnerProvider).selectedDevice;
    final recordingState = ref.watch(recordingProvider);
    final previewReady = ref.watch(previewProvider).isDriverReady;

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
      return const Center(
        child: Text(
          'Open a project to record actions',
          style: TextStyle(fontSize: 14, color: PatrolColors.steel),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPrepareSection(project, device, recordingState, previewReady),
        const Divider(height: 1, color: PatrolColors.pebble),
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
    bool previewReady,
  ) {
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
          TextField(
            controller: _recordingNameController,
            enabled: !_isSaving && !_isImporting,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Recording name',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: RecordingEnvironmentProfile.values.map((profile) {
              final selected = _environmentProfile == profile;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: TextButton(
                    onPressed: (_isSaving || _isImporting)
                        ? null
                        : () => setState(() => _environmentProfile = profile),
                    style: TextButton.styleFrom(
                      backgroundColor:
                          selected ? PatrolColors.ink : PatrolColors.fog,
                      foregroundColor:
                          selected ? PatrolColors.obsidian : PatrolColors.steel,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(profile.toJson()),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            previewReady
                ? 'Interact inside Patroller\'s simulator preview — taps and swipes are recorded automatically.'
                : 'Preview unavailable — interact in Simulator.app and Patroller will record from the native window.',
            style: const TextStyle(fontSize: 11, color: PatrolColors.steel),
          ),
          const SizedBox(height: 12),
          const _SectionHeading('Record'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: recordingState.isRecording
                      ? (_isSaving ? null : () => _saveActive(project, device))
                      : () => ref.read(recordingProvider.notifier).startRecording(),
                  icon: Icon(
                    recordingState.isRecording ? Icons.save : Icons.fiber_manual_record,
                    size: 14,
                  ),
                  label: Text(
                    recordingState.isRecording
                        ? (_isSaving ? 'Saving...' : 'Save')
                        : 'Record',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: recordingState.isRecording
                        ? PatrolColors.ember
                        : PatrolColors.red400,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: recordingState.isRecording
                      ? () => ref.read(recordingProvider.notifier).cancelRecording()
                      : null,
                  icon: Icon(
                    recordingState.isRecording ? Icons.close : Icons.stop,
                    size: 14,
                  ),
                  label: Text(recordingState.isRecording ? 'Cancel' : 'Stop'),
                ),
              ),
            ],
          ),
          if (recordingState.isRecording) ...[
            const SizedBox(height: 8),
            Text(
              previewReady
                  ? '${recordingState.activeActions.length} actions captured in preview. Logs attach on save.'
                  : 'Use Simulator.app to interact. ${recordingState.activeActions.length} actions captured. Logs attach on save.',
              style: const TextStyle(fontSize: 11, color: PatrolColors.steel),
            ),
            if (recordingState.activeActions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 112),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PatrolColors.obsidian,
                  borderRadius: BorderRadius.circular(10),
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
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text(
              'Import JSON',
              style: TextStyle(fontSize: 11, color: PatrolColors.steel),
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
                  if (_importError != null) setState(() => _importError = null);
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: (!_importController.text.trim().isEmpty && !_isImporting)
                    ? () => _importFromJson(project.projectPath)
                    : null,
                icon: const Icon(Icons.upload, size: 14),
                label: Text(_isImporting ? 'Importing...' : 'Import'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSavedList(RecordingState recordingState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: _SectionHeading('Saved Recordings'),
        ),
        Expanded(
          child: recordingState.recordings.isEmpty
              ? const Center(
                  child: Text(
                    'No recordings saved',
                    style: TextStyle(fontSize: 12, color: PatrolColors.steel),
                  ),
                )
              : ListView.builder(
                  itemCount: recordingState.recordings.length,
                  itemBuilder: (context, index) {
                    final recording = recordingState.recordings[index];
                    final selected = _selectedRecording?.id == recording.id;
                    return Material(
                      color: selected
                          ? PatrolColors.pebble.withValues(alpha: 0.6)
                          : Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() {
                          _selectedRecording =
                              selected ? null : recording;
                          _savedTestPath = null;
                          _renameValue = null;
                          _codePreview = null;
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
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: PatrolColors.ink,
                                ),
                              ),
                              Text(
                                '${recording.actionCount} actions · ${recording.environmentProfile.toJson()} · ${_formatDuration(recording.durationMs)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: PatrolColors.steel,
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
    final latestReplay =
        recording.replayResults.isNotEmpty ? recording.replayResults.first : null;
    final warnings = _collectWarnings(recording.actions);

    return Container(
      constraints: const BoxConstraints(maxHeight: 360),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: PatrolColors.pebble)),
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
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: PatrolColors.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 14, color: PatrolColors.steel),
                    onPressed: () => setState(() => _renameValue = recording.name),
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
              'Device: ${recording.deviceName ?? 'Any selected simulator'}',
              style: const TextStyle(fontSize: 10, color: PatrolColors.steel),
            ),
            Text(
              'Logs: ${recording.logs.length} · Snapshots: ${recording.stateSnapshots.length}',
              style: const TextStyle(fontSize: 10, color: PatrolColors.steel),
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
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 128),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: PatrolColors.obsidian,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                child: _ActionTimeline(actions: recording.actions),
              ),
            ),
            const SizedBox(height: 12),
            const _SectionHeading('Actions'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (recordingState.isReplaying || device == null)
                        ? null
                        : () => ref
                            .read(recordingProvider.notifier)
                            .replayRecording(recording, device),
                    icon: const Icon(Icons.play_arrow, size: 14),
                    label: Text(
                      recordingState.isReplaying ? 'Replaying' : 'Replay',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _saveTest(project.projectPath, recording.id),
                    icon: const Icon(Icons.save, size: 14),
                    label: const Text('Save Test'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
              Text(
                'Saved: $_savedTestPath',
                style: const TextStyle(fontSize: 10, color: PatrolColors.psPassed),
              ),
            if (latestReplay != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PatrolColors.fog,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: PatrolColors.pebble),
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
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loadingCodePreview
                  ? null
                  : () => _toggleCodePreview(recording, project.projectPath),
              icon: const Icon(Icons.code, size: 14),
              label: Text(
                _loadingCodePreview
                    ? 'Loading preview...'
                    : _codePreview != null
                        ? 'Hide code preview'
                        : 'Preview generated code',
              ),
            ),
            if (_codePreview != null) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 192),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PatrolColors.obsidian,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _codePreview!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: PatrolColors.graphite,
                    ),
                  ),
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
    final testFile = await ref
        .read(recordingProvider.notifier)
        .saveTestFile(recordingId, projectPath);
    if (testFile != null) {
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

  Future<void> _toggleCodePreview(Recording recording, String projectPath) async {
    if (_codePreview != null) {
      setState(() => _codePreview = null);
      return;
    }
    setState(() => _loadingCodePreview = true);
    try {
      final exported = await ref
          .read(recordingProvider.notifier)
          .exportRecording(recording.id, projectPath);
      if (exported != null) {
        setState(() => _codePreview = exported.patrolTest);
      }
    } finally {
      if (mounted) setState(() => _loadingCodePreview = false);
    }
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
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: PatrolColors.steel,
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
                style: const TextStyle(fontSize: 10, color: PatrolColors.ink),
              ),
              Text(
                'Delay ${action.delayMs}ms',
                style: const TextStyle(fontSize: 9, color: PatrolColors.steel),
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
    }
  }
}