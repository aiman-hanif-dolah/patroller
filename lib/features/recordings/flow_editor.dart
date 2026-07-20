import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/flow_editor.dart';
import '../../models/recording.dart';
import '../../services/recording_export.dart';

/// Visual Flow Editor: editable steps + inspector + live Patrol code preview.
class FlowEditorView extends StatefulWidget {
  const FlowEditorView({
    super.key,
    required this.recording,
    required this.onActionsChanged,
    required this.onSaveTest,
    required this.onSaveAndDevelop,
    required this.onSaveAndTest,
    required this.onReplay,
    this.canReplay = true,
    this.isReplaying = false,
    this.isBusy = false,
  });

  final Recording recording;
  final Future<void> Function(List<RecordingAction> actions) onActionsChanged;
  final VoidCallback onSaveTest;
  final VoidCallback onSaveAndDevelop;
  final VoidCallback onSaveAndTest;
  final VoidCallback onReplay;
  final bool canReplay;
  final bool isReplaying;
  final bool isBusy;

  @override
  State<FlowEditorView> createState() => _FlowEditorViewState();
}

class _FlowEditorViewState extends State<FlowEditorView> {
  late List<RecordingAction> _actions;
  String? _selectedId;
  final _labelController = TextEditingController();
  final _delayController = TextEditingController();
  final _textController = TextEditingController();
  bool _persisting = false;

  @override
  void initState() {
    super.initState();
    _syncFromRecording(widget.recording);
  }

  @override
  void didUpdateWidget(covariant FlowEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recording.id != widget.recording.id ||
        oldWidget.recording.updatedAt != widget.recording.updatedAt ||
        oldWidget.recording.actionCount != widget.recording.actionCount) {
      _syncFromRecording(widget.recording);
    }
  }

  void _syncFromRecording(Recording recording) {
    _actions = List<RecordingAction>.from(recording.actions);
    if (_selectedId == null ||
        !_actions.any((a) => a.id == _selectedId)) {
      _selectedId = _actions.isNotEmpty ? _actions.first.id : null;
    }
    _loadInspector();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _delayController.dispose();
    _textController.dispose();
    super.dispose();
  }

  RecordingAction? get _selected {
    final id = _selectedId;
    if (id == null) return null;
    for (final a in _actions) {
      if (a.id == id) return a;
    }
    return null;
  }

  void _loadInspector() {
    final step = _selected;
    if (step == null) {
      _labelController.clear();
      _delayController.clear();
      _textController.clear();
      return;
    }
    _labelController.text = step.targetLabel ?? step.text ?? '';
    _delayController.text = '${step.delayMs}';
    _textController.text = step.text ?? '';
  }

  String get _codePreview {
    final draft = widget.recording.copyWith(
      actions: _actions,
      actionCount: _actions.length,
    );
    return toPatrolTest(draft);
  }

  Future<void> _commit(List<RecordingAction> next) async {
    if (_persisting || widget.isBusy) return;
    setState(() {
      _actions = next;
      if (_selectedId != null && !next.any((a) => a.id == _selectedId)) {
        _selectedId = next.isNotEmpty ? next.first.id : null;
      }
      _loadInspector();
      _persisting = true;
    });
    try {
      await widget.onActionsChanged(next);
    } finally {
      if (mounted) setState(() => _persisting = false);
    }
  }

  Future<void> _select(String id) async {
    setState(() {
      _selectedId = id;
      _loadInspector();
    });
  }

  Future<void> _applyInspector() async {
    final step = _selected;
    if (step == null) return;
    final delay = int.tryParse(_delayController.text.trim()) ?? step.delayMs;
    final label = _labelController.text;
    final text = _textController.text;
    final patched = patchFlowStep(
      step,
      targetLabel: label.trim().isEmpty ? null : label.trim(),
      clearTargetLabel: label.trim().isEmpty,
      delayMs: delay.clamp(0, 60000),
      text: step.type == RecordingActionType.text ||
              step.type == RecordingActionType.assertVisible
          ? text
          : step.text,
    );
    // Keep assert finder in both fields when present.
    final finalStep = step.type == RecordingActionType.assertVisible
        ? RecordingAction(
            id: patched.id,
            type: patched.type,
            timestampMs: patched.timestampMs,
            delayMs: patched.delayMs,
            targetLabel: label.trim().isEmpty ? null : label.trim(),
            text: label.trim().isEmpty ? null : label.trim(),
          )
        : patched;
    await _commit(replaceFlowStep(_actions, finalStep));
  }

  Future<void> _deleteSelected() async {
    final id = _selectedId;
    if (id == null) return;
    await _commit(removeFlowStep(_actions, id));
  }

  Future<void> _moveSelected(int delta) async {
    final id = _selectedId;
    if (id == null) return;
    await _commit(moveFlowStep(_actions, id, delta));
  }

  Future<void> _insertAssert() async {
    final index = _selectedId == null
        ? _actions.length
        : _actions.indexWhere((a) => a.id == _selectedId) + 1;
    final next = insertAssertVisible(
      _actions,
      index: index < 0 ? _actions.length : index,
      label: 'Screen title',
    );
    final inserted = next[index.clamp(0, next.length - 1)];
    // Prefer the new assert if we can find it.
    final created = next.firstWhere(
      (a) =>
          a.type == RecordingActionType.assertVisible &&
          !_actions.any((b) => b.id == a.id),
      orElse: () => inserted,
    );
    setState(() => _selectedId = created.id);
    await _commit(next);
  }

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final busy = widget.isBusy || _persisting || widget.isReplaying;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FlowHeading('Flow Editor'),
        const SizedBox(height: 4),
        Text(
          'Edit steps, insert asserts, then Save Test or Save & Develop. '
          'Changes persist to the recording.',
          style: TextStyle(fontSize: 10, color: p.textMuted, height: 1.35),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _MiniBtn(
              icon: Icons.add_task_outlined,
              label: 'Insert assert',
              color: PatrolColors.sky400,
              enabled: !busy,
              onPressed: _insertAssert,
            ),
            _MiniBtn(
              icon: Icons.arrow_upward,
              label: 'Up',
              color: p.textMuted,
              enabled: !busy && _selectedId != null,
              onPressed: () => _moveSelected(-1),
            ),
            _MiniBtn(
              icon: Icons.arrow_downward,
              label: 'Down',
              color: p.textMuted,
              enabled: !busy && _selectedId != null,
              onPressed: () => _moveSelected(1),
            ),
            _MiniBtn(
              icon: Icons.delete_outline,
              label: 'Delete',
              color: PatrolColors.red400,
              enabled: !busy && _selectedId != null,
              onPressed: _deleteSelected,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: p.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.border),
                ),
                child: _actions.isEmpty
                    ? Center(
                        child: Text(
                          'No steps - record or insert an assert',
                          style: TextStyle(fontSize: 11, color: p.textMuted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _actions.length,
                        itemBuilder: (context, index) {
                          final action = _actions[index];
                          final selected = action.id == _selectedId;
                          return Material(
                            color: selected
                                ? PatrolColors.amber.withValues(alpha: 0.12)
                                : Colors.transparent,
                            child: InkWell(
                              onTap: () => _select(action.id),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _iconFor(action.type),
                                      size: 14,
                                      color: selected
                                          ? PatrolColors.amber
                                          : p.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${index + 1}. ${flowStepTitle(action)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: p.text,
                                            ),
                                          ),
                                          Text(
                                            flowStepSubtitle(action),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: p.textMuted,
                                            ),
                                          ),
                                        ],
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
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _InspectorPane(
                selected: _selected,
                labelController: _labelController,
                delayController: _delayController,
                textController: _textController,
                enabled: !busy && _selected != null,
                onApply: _applyInspector,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            FilledButton.icon(
              onPressed: (!widget.canReplay || busy) ? null : widget.onReplay,
              icon: Icon(
                widget.isReplaying ? Icons.hourglass_top : Icons.play_arrow,
                size: 14,
              ),
              label: Text(widget.isReplaying ? 'Replaying…' : 'Replay'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : widget.onSaveTest,
              icon: const Icon(Icons.save_outlined, size: 14),
              label: const Text('Save Test'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: PatrolColors.violet500,
              ),
              onPressed: busy ? null : widget.onSaveAndDevelop,
              icon: const Icon(Icons.science_outlined, size: 14),
              label: const Text('Save & Develop'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : widget.onSaveAndTest,
              icon: const Icon(Icons.play_circle_outline, size: 14),
              label: const Text('Save & Test'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const _FlowHeading('Generated Patrol code'),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: p.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _codePreview));
                    if (context.mounted) {
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(
                          content: Text('Patrol code copied'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy, size: 12),
                  label: const Text('Copy', style: TextStyle(fontSize: 10)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: PatrolColors.sky400,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    _codePreview,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: p.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_persisting)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Saving flow…',
              style: TextStyle(fontSize: 10, color: p.textMuted),
            ),
          ),
      ],
    );
  }

  static IconData _iconFor(RecordingActionType type) {
    return switch (type) {
      RecordingActionType.tap => Icons.touch_app_outlined,
      RecordingActionType.longpress => Icons.pan_tool_outlined,
      RecordingActionType.swipe => Icons.swipe_outlined,
      RecordingActionType.text => Icons.keyboard_outlined,
      RecordingActionType.key => Icons.keyboard_command_key,
      RecordingActionType.assertVisible => Icons.visibility_outlined,
    };
  }
}

class _InspectorPane extends StatelessWidget {
  const _InspectorPane({
    required this.selected,
    required this.labelController,
    required this.delayController,
    required this.textController,
    required this.enabled,
    required this.onApply,
  });

  final RecordingAction? selected;
  final TextEditingController labelController;
  final TextEditingController delayController;
  final TextEditingController textController;
  final bool enabled;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    if (selected == null) {
      return Container(
        constraints: const BoxConstraints(minHeight: 120, maxHeight: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: p.border),
        ),
        child: Text(
          'Select a step',
          style: TextStyle(fontSize: 11, color: p.textMuted),
        ),
      );
    }

    final showTextField = selected!.type == RecordingActionType.text;
    final showLabel = selected!.type != RecordingActionType.key &&
        selected!.type != RecordingActionType.swipe;

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Inspector · ${selected!.type.name}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: p.text,
              ),
            ),
            const SizedBox(height: 6),
            if (showLabel) ...[
              Text('Finder / label', style: TextStyle(fontSize: 9, color: p.textMuted)),
              const SizedBox(height: 2),
              TextField(
                controller: labelController,
                enabled: enabled,
                style: const TextStyle(fontSize: 11),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (showTextField) ...[
              Text('Text value', style: TextStyle(fontSize: 9, color: p.textMuted)),
              const SizedBox(height: 2),
              TextField(
                controller: textController,
                enabled: enabled,
                style: const TextStyle(fontSize: 11),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text('Delay (ms)', style: TextStyle(fontSize: 9, color: p.textMuted)),
            const SizedBox(height: 2),
            TextField(
              controller: delayController,
              enabled: enabled,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 11),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: enabled ? onApply : null,
              child: const Text('Apply', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowHeading extends StatelessWidget {
  const _FlowHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: p.textMuted,
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
