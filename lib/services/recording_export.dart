import 'dart:convert';

import '../models/enums.dart';
import '../models/recording.dart';

String _deviceTypeLabel(DeviceType? deviceType) {
  return deviceType?.toJson() ?? 'unknown';
}

List<String> _actionToFlow(RecordingAction action) {
  final delay = action.delayMs > 0
      ? ['  delayMs: ${action.delayMs}']
      : <String>[];

  switch (action.type) {
    case RecordingActionType.tap:
      return [
        '- tap:',
        '  x: ${action.x?.round() ?? 0}',
        '  y: ${action.y?.round() ?? 0}',
        ...delay,
      ];
    case RecordingActionType.longpress:
      return [
        '- longPress:',
        '  x: ${action.x?.round() ?? 0}',
        '  y: ${action.y?.round() ?? 0}',
        '  durationSec: ${action.durationSec ?? 0.6}',
        ...delay,
      ];
    case RecordingActionType.swipe:
      return [
        '- swipe:',
        '  from: ${action.x?.round() ?? 0},${action.y?.round() ?? 0}',
        '  to: ${action.toX?.round() ?? action.x?.round() ?? 0},${action.toY?.round() ?? action.y?.round() ?? 0}',
        '  durationSec: ${action.durationSec ?? 0.2}',
        ...delay,
      ];
    case RecordingActionType.text:
      return [
        '- inputText:',
        '  text: ${jsonEncode(action.text ?? '')}',
        ...delay,
      ];
    case RecordingActionType.key:
      return [
        '- pressKey:',
        '  key: ${jsonEncode(action.key ?? '')}',
        ...delay,
      ];
    case RecordingActionType.assertVisible:
      final label = (action.targetLabel ?? action.text ?? '').trim();
      return [
        '- assertVisible:',
        '  text: ${jsonEncode(label)}',
        ...delay,
      ];
  }
}

String _dartString(String value) {
  return jsonEncode(value).replaceAll(r'$', r'\$');
}

String _testName(Recording recording) {
  return '${recording.name} [${recording.environmentProfile.toJson()}]';
}

String _settleLine() {
  return '    await \$.tester.pumpAndSettle(timeout: const Duration(seconds: 10));';
}

int _durationMs(double? seconds, double fallback) {
  return (((seconds ?? fallback) * 1000).round()).clamp(1, 1 << 31);
}

bool _hasStableTargetLabel(RecordingAction action) {
  return action.targetLabel != null && action.targetLabel!.trim().isNotEmpty;
}

const _defaultLongPressSec = 0.6;

bool _longPressUsesCustomDuration(RecordingAction action) {
  final duration = action.durationSec;
  if (duration == null) return false;
  return (duration - _defaultLongPressSec).abs() > 0.05;
}

(int, int) _longPressCenter(RecordingAction action) {
  final frame = action.targetFrame;
  if (frame != null) {
    return (
      (frame.x + frame.width / 2).round(),
      (frame.y + frame.height / 2).round(),
    );
  }
  return ((action.x ?? 0).round(), (action.y ?? 0).round());
}

List<String> _stateGuardLines(
  RecordingAction action,
  Map<String, RecordingStateSnapshot> snapshots,
) {
  if (action.stateChanged != true) return const [];
  final fingerprint = action.screenFingerprint;
  if (fingerprint == null) return const [];
  final snapshot = snapshots[fingerprint];
  if (snapshot == null) return const [];
  final anchor = snapshot.visibleTexts
      .where((text) => text != action.targetLabel)
      .firstOrNull;
  if (anchor == null) return const [];
  return ['    await \$(${_dartString(anchor)}).waitUntilVisible();'];
}

String _dartKey(String? key) {
  switch (key?.toUpperCase()) {
    case 'ENTER':
      return 'enter';
    case 'ESCAPE':
      return 'escape';
    case 'BACKSPACE':
      return 'backspace';
    case 'DELETE':
      return 'delete';
    case 'TAB':
      return 'tab';
    case 'SPACE':
      return 'space';
    default:
      return 'enter';
  }
}

List<String> _actionToPatrol(
  RecordingAction action,
  Map<String, RecordingStateSnapshot> snapshots,
) {
  final lines = <String>[];
  if (action.delayMs > 0) {
    lines.add(
      '    await Future<void>.delayed(const Duration(milliseconds: ${action.delayMs}));',
    );
  }

  switch (action.type) {
    case RecordingActionType.tap:
      if (_hasStableTargetLabel(action)) {
        lines.add(
          '    await \$(${_dartString(action.targetLabel!.trim())}).tap();',
        );
      } else {
        lines.add(
          '    await \$.tester.tapAt(const Offset(${action.x?.round() ?? 0}, ${action.y?.round() ?? 0}));',
        );
      }
      lines.add(_settleLine());
      lines.addAll(_stateGuardLines(action, snapshots));
    case RecordingActionType.longpress:
      if (_hasStableTargetLabel(action) &&
          !_longPressUsesCustomDuration(action)) {
        lines.add(
          '    await \$.tester.longPress(\$(${_dartString(action.targetLabel!.trim())}));',
        );
      } else {
        final (x, y) = _longPressCenter(action);
        if (_hasStableTargetLabel(action)) {
          lines.add(
            '    // longPress on ${_dartString(action.targetLabel!.trim())}',
          );
        }
        lines.add(
          '    await \$.tester.longPressAt(const Offset($x, $y), duration: const Duration(milliseconds: ${_durationMs(action.durationSec, _defaultLongPressSec)}));',
        );
      }
      lines.add(_settleLine());
      lines.addAll(_stateGuardLines(action, snapshots));
    case RecordingActionType.swipe:
      lines.add(
        '    await \$.tester.timedDragFrom(const Offset(${action.x?.round() ?? 0}, ${action.y?.round() ?? 0}), const Offset(${(action.toX ?? action.x ?? 0) - (action.x ?? 0)}, ${(action.toY ?? action.y ?? 0) - (action.y ?? 0)}), const Duration(milliseconds: ${_durationMs(action.durationSec, 0.2)}));',
      );
      lines.add(_settleLine());
      lines.addAll(_stateGuardLines(action, snapshots));
    case RecordingActionType.text:
      lines.add(
        "    expect(_focusedEditableText(), findsOneWidget, reason: 'Expected a focused text field before entering text');",
      );
      lines.add(
        '    await \$.tester.enterText(_focusedEditableText(), ${_dartString(action.text ?? '')});',
      );
      lines.add(_settleLine());
    case RecordingActionType.key:
      lines.add(
        '    await \$.tester.sendKeyEvent(LogicalKeyboardKey.${_dartKey(action.key)});',
      );
      lines.add(_settleLine());
    case RecordingActionType.assertVisible:
      final label = (action.targetLabel ?? action.text ?? '').trim();
      if (label.isEmpty) {
        lines.add(
          "    // assertVisible skipped — empty finder label",
        );
      } else {
        lines.add(
          '    await \$(${_dartString(label)}).waitUntilVisible();',
        );
      }
  }
  return lines;
}

List<RecordingAction> mergeTextActions(List<RecordingAction> actions) {
  final merged = <RecordingAction>[];
  RecordingAction? pendingText;
  var pendingTextValue = '';

  for (final action in actions) {
    if (action.type == RecordingActionType.text) {
      if (pendingText != null) {
        pendingTextValue += action.text ?? '';
        pendingText = pendingText.copyWith(text: pendingTextValue);
      } else {
        pendingText = action;
        pendingTextValue = action.text ?? '';
      }
      continue;
    }
    if (pendingText != null) {
      merged.add(pendingText);
      pendingText = null;
      pendingTextValue = '';
    }
    merged.add(action);
  }
  if (pendingText != null) {
    merged.add(pendingText.copyWith(text: pendingTextValue));
  }
  return merged;
}

Map<String, RecordingStateSnapshot> _snapshotsByFingerprint(Recording recording) {
  final map = <String, RecordingStateSnapshot>{};
  for (final snapshot in recording.stateSnapshots) {
    map.putIfAbsent(snapshot.screenFingerprint, () => snapshot);
  }
  return map;
}

String toPatrolTest(Recording recording) {
  final actions = mergeTextActions(recording.actions);
  final snapshots = _snapshotsByFingerprint(recording);
  final needsHelper =
      actions.any((a) => a.type == RecordingActionType.text);

  final lines = <String>[
    "import 'dart:ui';",
    '',
    "import 'package:flutter/services.dart';",
    "import 'package:flutter/widgets.dart';",
    "import 'package:flutter_test/flutter_test.dart';",
    "import 'package:patrol/patrol.dart';",
    '',
    'void main() {',
    '  patrolTest(${_dartString(_testName(recording))}, (\$) async {',
    '    // Recording: ${recording.id}',
    '    // Environment: ${recording.environmentProfile.toJson()}',
    '    // Actions: ${actions.length}',
  ];

  for (final action in actions) {
    lines.addAll(_actionToPatrol(action, snapshots));
  }

  lines.add('  });');
  if (needsHelper) {
    lines.addAll([
      '',
      '  Finder _focusedEditableText() {',
      '    return find.byWidgetPredicate((widget) =>',
      '        widget is EditableText && widget.focusNode.hasFocus);',
      '  }',
    ]);
  }
  lines.add('}');
  lines.add('');
  return lines.join('\n');
}

RecordingExport exportRecording(Recording recording) {
  final flow = <String>[
    'name: ${jsonEncode(recording.name)}',
    'recordingId: ${recording.id}',
    'deviceType: ${_deviceTypeLabel(recording.deviceType)}',
    'environmentProfile: ${recording.environmentProfile.toJson()}',
    'actions:',
  ];
  for (final action in recording.actions) {
    for (final line in _actionToFlow(action)) {
      flow.add('  $line');
    }
  }
  flow.add('');

  final logs = recording.logs
      .map((log) =>
          '[${log.timestamp}] [${log.streamType.toJson()}] ${log.text}')
      .join('\n');

  final replayLogs = recording.replayResults.asMap().entries.map((entry) {
    final index = entry.key;
    final result = entry.value;
    final label =
        result.source == 'generated-test' ? 'Generated test' : 'Studio replay';
    final header =
        '$label ${index + 1}: ${result.status} · ${result.actionCount} actions · ${result.startedAt}';
    final body = result.logs
        .map((log) =>
            '[${log.timestamp}] [${log.streamType.toJson()}] ${log.text}')
        .join('\n');
    return '$header\n$body';
  }).join('\n\n');

  return RecordingExport(
    recordingId: recording.id,
    json: const JsonEncoder.withIndent('  ').convert(recording.toJson()),
    flow: flow.join('\n'),
    logs: logs,
    replayLogs: replayLogs,
    patrolTest: toPatrolTest(recording),
  );
}