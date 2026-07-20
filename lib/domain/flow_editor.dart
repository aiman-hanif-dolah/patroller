import 'package:uuid/uuid.dart';

import '../models/recording.dart';

const _uuid = Uuid();

/// Human-readable title for a flow step (list rows + inspector).
String flowStepTitle(RecordingAction action) {
  final label = (action.targetLabel ?? action.text)?.trim();
  switch (action.type) {
    case RecordingActionType.tap:
      return label != null && label.isNotEmpty ? 'tap "$label"' : 'tap';
    case RecordingActionType.longpress:
      return label != null && label.isNotEmpty
          ? 'long press "$label"'
          : 'long press';
    case RecordingActionType.swipe:
      return 'swipe';
    case RecordingActionType.text:
      final t = action.text ?? '';
      final short = t.length > 24 ? '${t.substring(0, 24)}…' : t;
      return t.isEmpty ? 'enter text' : 'enter "$short"';
    case RecordingActionType.key:
      return 'key ${action.key ?? ''}';
    case RecordingActionType.assertVisible:
      return label != null && label.isNotEmpty
          ? 'assert "$label" visible'
          : 'assert visible';
  }
}

/// Subtitle metadata for a step row.
String flowStepSubtitle(RecordingAction action) {
  final parts = <String>[];
  if (action.delayMs > 0) {
    parts.add('+${action.delayMs}ms');
  }
  switch (action.type) {
    case RecordingActionType.tap:
    case RecordingActionType.longpress:
      if (action.x != null && action.y != null) {
        parts.add('${action.x!.round()},${action.y!.round()}');
      }
    case RecordingActionType.swipe:
      if (action.x != null && action.y != null) {
        parts.add(
          '${action.x!.round()},${action.y!.round()} → '
          '${(action.toX ?? action.x)!.round()},${(action.toY ?? action.y)!.round()}',
        );
      }
    case RecordingActionType.text:
    case RecordingActionType.key:
    case RecordingActionType.assertVisible:
      break;
  }
  return parts.isEmpty ? action.type.name : parts.join(' · ');
}

List<RecordingAction> removeFlowStep(
  List<RecordingAction> actions,
  String id,
) {
  return actions.where((a) => a.id != id).toList(growable: false);
}

/// Move step by [delta] positions (−1 up, +1 down). No-op at bounds or missing id.
List<RecordingAction> moveFlowStep(
  List<RecordingAction> actions,
  String id,
  int delta,
) {
  if (delta == 0 || actions.isEmpty) {
    return List<RecordingAction>.from(actions);
  }
  final index = actions.indexWhere((a) => a.id == id);
  if (index < 0) return List<RecordingAction>.from(actions);
  final next = (index + delta).clamp(0, actions.length - 1);
  if (next == index) return List<RecordingAction>.from(actions);
  final list = List<RecordingAction>.from(actions);
  final item = list.removeAt(index);
  list.insert(next, item);
  return list;
}

RecordingAction patchFlowStep(
  RecordingAction action, {
  String? targetLabel,
  int? delayMs,
  String? text,
  String? key,
  double? x,
  double? y,
  double? toX,
  double? toY,
  bool clearTargetLabel = false,
}) {
  // Rebuild so targetLabel can be cleared (copyWith treats null as "keep").
  return RecordingAction(
    id: action.id,
    type: action.type,
    timestampMs: action.timestampMs,
    delayMs: delayMs ?? action.delayMs,
    x: x ?? action.x,
    y: y ?? action.y,
    toX: toX ?? action.toX,
    toY: toY ?? action.toY,
    durationSec: action.durationSec,
    text: text ?? action.text,
    key: key ?? action.key,
    targetLabel: clearTargetLabel
        ? null
        : (targetLabel ?? action.targetLabel),
    targetType: action.targetType,
    targetFrame: action.targetFrame,
    screenFingerprint: action.screenFingerprint,
    stateSummary: action.stateSummary,
    stateChanged: action.stateChanged,
  );
}

/// Insert an assertVisible step at [index] (clamped). Uses [label] as finder.
List<RecordingAction> insertAssertVisible(
  List<RecordingAction> actions, {
  required int index,
  required String label,
  String? id,
  int delayMs = 0,
}) {
  final trimmed = label.trim();
  final insertAt = index.clamp(0, actions.length);
  final neighborTs = insertAt > 0
      ? actions[insertAt - 1].timestampMs
      : (actions.isNotEmpty ? actions.first.timestampMs : 0);
  final step = RecordingAction(
    id: id ?? 'act_assert_${_uuid.v4()}',
    type: RecordingActionType.assertVisible,
    timestampMs: neighborTs,
    delayMs: delayMs,
    targetLabel: trimmed.isEmpty ? null : trimmed,
    text: trimmed.isEmpty ? null : trimmed,
  );
  final list = List<RecordingAction>.from(actions);
  list.insert(insertAt, step);
  return list;
}

/// Apply a patched step by id; returns a new list.
List<RecordingAction> replaceFlowStep(
  List<RecordingAction> actions,
  RecordingAction updated,
) {
  return [
    for (final a in actions) a.id == updated.id ? updated : a,
  ];
}
