import '../models/hierarchy.dart';
import '../models/recording.dart';
import 'hierarchy_analysis.dart';
import 'state_snapshot.dart';

class ActionTargetPatch {
  const ActionTargetPatch({
    this.targetLabel,
    this.targetType,
    this.targetFrame,
  });

  final String? targetLabel;
  final String? targetType;
  final ElementFrame? targetFrame;
}

({double x, double y}) pixelsToPoints(
  XCTestDeviceInfo? deviceInfo,
  double xPx,
  double yPx,
) {
  if (deviceInfo == null ||
      deviceInfo.widthPixels == 0 ||
      deviceInfo.widthPoints == 0) {
    return (x: xPx, y: yPx);
  }
  final scaleX = deviceInfo.widthPixels / deviceInfo.widthPoints;
  final scaleY = deviceInfo.heightPixels != 0 && deviceInfo.heightPoints != 0
      ? deviceInfo.heightPixels / deviceInfo.heightPoints
      : scaleX;
  return (
    x: xPx / (scaleX < 1 ? 1 : scaleX),
    y: yPx / (scaleY < 1 ? 1 : scaleY),
  );
}

ActionTargetPatch deriveActionTarget(
  RecordingAction action,
  HierarchyNode? hierarchy,
  XCTestDeviceInfo? deviceInfo,
) {
  if (hierarchy == null) return const ActionTargetPatch();
  if ((action.type != RecordingActionType.tap &&
          action.type != RecordingActionType.longpress) ||
      action.x == null ||
      action.y == null) {
    return const ActionTargetPatch();
  }
  final point = pixelsToPoints(deviceInfo, action.x!, action.y!);
  final match = findNearestElement(hierarchy, point.x, point.y);
  if (match == null) return const ActionTargetPatch();
  return ActionTargetPatch(
    targetLabel: match.label,
    targetType: match.type,
    targetFrame: match.frame,
  );
}

class StateObservation {
  const StateObservation({
    required this.screenFingerprint,
    required this.stateChanged,
    this.stateSummary,
    this.snapshot,
  });

  final String screenFingerprint;
  final bool stateChanged;
  final String? stateSummary;
  final RecordingStateSnapshot? snapshot;
}

StateObservation observeStateAfterAction(
  HierarchyNode hierarchy,
  String? previousFingerprint,
  String snapshotId,
  int timestampMs,
) {
  final snapshot = deriveStateSnapshot(hierarchy, snapshotId, timestampMs);
  final stateChanged = previousFingerprint != null &&
      snapshot.screenFingerprint != previousFingerprint;
  final summary = summarizeSnapshot(snapshot);
  return StateObservation(
    screenFingerprint: snapshot.screenFingerprint,
    stateChanged: stateChanged,
    stateSummary: summary.isEmpty ? null : summary,
    snapshot: stateChanged ? snapshot : null,
  );
}

enum ActionWarningKind {
  coordinateOnly,
  noStateChange,
  noStableLabel,
}

List<ActionWarningKind> deriveActionWarnings(RecordingAction action) {
  final warnings = <ActionWarningKind>[];
  final isPointerAction = action.type == RecordingActionType.tap ||
      action.type == RecordingActionType.longpress;
  final hasLabel =
      action.targetLabel != null && action.targetLabel!.trim().isNotEmpty;

  if (isPointerAction && !hasLabel && action.screenFingerprint != null) {
    warnings.add(ActionWarningKind.coordinateOnly);
  }
  if (isPointerAction && action.stateChanged == false) {
    warnings.add(ActionWarningKind.noStateChange);
  }
  if (action.stateChanged == true && !hasLabel && isPointerAction) {
    warnings.add(ActionWarningKind.noStableLabel);
  }
  return warnings;
}

const actionWarningLabels = <ActionWarningKind, String>{
  ActionWarningKind.coordinateOnly:
      'Coordinate-only: no stable element label was captured for this action.',
  ActionWarningKind.noStateChange:
      'No visible state change was detected after this action.',
  ActionWarningKind.noStableLabel:
      'State changed but no stable label was captured; replay uses coordinates.',
};