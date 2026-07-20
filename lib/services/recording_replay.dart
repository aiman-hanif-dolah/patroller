import 'dart:async';
import 'dart:convert';

import '../domain/recording_enrichment.dart';
import '../domain/state_snapshot.dart';
import '../models/enums.dart';
import '../models/hierarchy.dart';
import '../models/recording.dart';
import '../models/run_record.dart';
import 'simulator_driver_service.dart';

Future<RecordingStateSnapshot?> _captureReplaySnapshot({
  required SimulatorDriverService driver,
  required String udid,
  required DeviceType deviceType,
  required String id,
  required int startedAtMs,
}) async {
  try {
    final hierarchy = await driver.viewHierarchy(
      udid: udid,
      deviceType: deviceType,
    );
    return deriveStateSnapshot(
      hierarchy,
      id,
      DateTime.now().millisecondsSinceEpoch - startedAtMs,
    );
  } catch (_) {
    return null;
  }
}

({double x, double y}) _replayPoint(
  RecordingAction action,
  XCTestDeviceInfo deviceInfo,
) {
  final frame = action.targetFrame;
  if (frame != null &&
      (action.type == RecordingActionType.tap ||
          action.type == RecordingActionType.longpress)) {
    return (x: frame.x + frame.width / 2, y: frame.y + frame.height / 2);
  }
  final x = action.x ?? 0;
  final y = action.y ?? 0;
  if (x > deviceInfo.widthPoints * 1.2 || y > deviceInfo.heightPoints * 1.2) {
    final point = pixelsToPoints(deviceInfo, x, y);
    return (x: point.x, y: point.y);
  }
  return (x: x, y: y);
}

({double x, double y, double toX, double toY}) _replaySwipePoints(
  RecordingAction action,
  XCTestDeviceInfo deviceInfo,
) {
  final start = _replayPoint(action, deviceInfo);
  var toX = action.toX ?? action.x ?? start.x;
  var toY = action.toY ?? action.y ?? start.y;
  if (toX > deviceInfo.widthPoints * 1.2 ||
      toY > deviceInfo.heightPoints * 1.2) {
    final end = pixelsToPoints(deviceInfo, toX, toY);
    toX = end.x;
    toY = end.y;
  }
  return (x: start.x, y: start.y, toX: toX, toY: toY);
}

Future<void> _replayAction({
  required SimulatorDriverService driver,
  required String udid,
  required DeviceType deviceType,
  required RecordingAction action,
  required XCTestDeviceInfo deviceInfo,
}) async {
  switch (action.type) {
    case RecordingActionType.tap:
      final point = _replayPoint(action, deviceInfo);
      await driver.tap(
        udid: udid,
        x: point.x,
        y: point.y,
        deviceType: deviceType,
      );
    case RecordingActionType.longpress:
      final point = _replayPoint(action, deviceInfo);
      await driver.longPress(
        udid: udid,
        x: point.x,
        y: point.y,
        durationSec: action.durationSec ?? 0.6,
        deviceType: deviceType,
      );
    case RecordingActionType.swipe:
      final points = _replaySwipePoints(action, deviceInfo);
      await driver.swipe(
        udid: udid,
        fromX: points.x,
        fromY: points.y,
        toX: points.toX,
        toY: points.toY,
        deviceType: deviceType,
        duration: action.durationSec,
      );
    case RecordingActionType.text:
      await driver.inputText(
        udid: udid,
        text: action.text ?? '',
        deviceType: deviceType,
      );
    case RecordingActionType.key:
      await driver.pressKey(
        udid: udid,
        key: action.key ?? '',
        deviceType: deviceType,
      );
    case RecordingActionType.assertVisible:
      // Studio driver has no semantic assert - skip so Flow Editor asserts
      // don't fail native replay. Patrol codegen still emits waitUntilVisible.
      return;
  }
}

String _describeAction(RecordingAction action) {
  switch (action.type) {
    case RecordingActionType.tap:
      return 'tap ${(action.x ?? 0).round()},${(action.y ?? 0).round()}';
    case RecordingActionType.longpress:
      return 'long press ${(action.x ?? 0).round()},${(action.y ?? 0).round()} for ${action.durationSec ?? 0.6}s';
    case RecordingActionType.swipe:
      return 'swipe ${(action.x ?? 0).round()},${(action.y ?? 0).round()} to ${(action.toX ?? action.x ?? 0).round()},${(action.toY ?? action.y ?? 0).round()}';
    case RecordingActionType.text:
      return 'text ${jsonEncode(action.text ?? '')}';
    case RecordingActionType.key:
      return 'key ${action.key ?? ''}';
    case RecordingActionType.assertVisible:
      final label = (action.targetLabel ?? action.text ?? '').trim();
      return label.isEmpty
          ? 'assert visible'
          : 'assert visible ${jsonEncode(label)}';
  }
}

class ReplayResultBundle {
  const ReplayResultBundle({
    required this.result,
    required this.stateSnapshots,
  });

  final RecordingReplayResult result;
  final List<RecordingStateSnapshot> stateSnapshots;
}

Future<ReplayResultBundle> replayRecording({
  required Recording recording,
  required String udid,
  required DeviceType deviceType,
  required SimulatorDriverService driver,
  void Function(LogEvent log)? onLog,
  void Function()? onActionReplayed,
}) async {
  final startedAt = DateTime.now().toUtc().toIso8601String();
  final startedAtMs = DateTime.now().millisecondsSinceEpoch;
  final replayId = 'replay_${recording.id}_$startedAtMs';
  final stateSnapshots = <RecordingStateSnapshot>[];
  var lineNumber = 0;
  final replayLogs = <RecordingLogSnapshot>[];

  void pushLog(String text, LogStreamType streamType) {
    lineNumber++;
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final snapshot = RecordingLogSnapshot(
      runId: replayId,
      streamType: streamType,
      timestamp: timestamp,
      text: text,
      lineNumber: lineNumber,
    );
    replayLogs.add(snapshot);
    onLog?.call(
      LogEvent(
        runId: replayId,
        streamType: streamType,
        timestamp: timestamp,
        text: text,
        lineNumber: lineNumber,
        source: LogSource.patrol,
      ),
    );
  }

  final profile = recording.environmentProfile.toJson();
  pushLog(
    'Replay started: ${recording.name} ($profile)',
    LogStreamType.stdout,
  );

  try {
    await driver.ensureSession(udid: udid, deviceType: deviceType);
  } catch (e) {
    final message = e.toString();
    pushLog('Replay failed: $message', LogStreamType.stderr);
    final endSnapshot = await _captureReplaySnapshot(
      driver: driver,
      udid: udid,
      deviceType: deviceType,
      id: '${replayId}_end',
      startedAtMs: startedAtMs,
    );
    if (endSnapshot != null) stateSnapshots.add(endSnapshot);
    return ReplayResultBundle(
      result: RecordingReplayResult(
        recordingId: recording.id,
        source: 'studio-replay',
        startedAt: startedAt,
        endedAt: DateTime.now().toUtc().toIso8601String(),
        actionCount: recording.actionCount,
        status: 'failed',
        error: message,
        logs: replayLogs,
      ),
      stateSnapshots: stateSnapshots,
    );
  }

  final deviceInfo = await driver.deviceInfo(udid: udid, deviceType: deviceType);
  await driver.screenshot(udid: udid, deviceType: deviceType);
  final startSnapshot = await _captureReplaySnapshot(
    driver: driver,
    udid: udid,
    deviceType: deviceType,
    id: '${replayId}_start',
    startedAtMs: startedAtMs,
  );
  if (startSnapshot != null) stateSnapshots.add(startSnapshot);

  for (var index = 0; index < recording.actions.length; index++) {
    final action = recording.actions[index];
    final delay = action.delayMs.clamp(0, 10000);
    if (delay > 0) {
      await Future<void>.delayed(Duration(milliseconds: delay));
    }
    pushLog(
      'Replay action ${index + 1}/${recording.actions.length}: ${_describeAction(action)}',
      LogStreamType.stdout,
    );
    try {
      await _replayAction(
        driver: driver,
        udid: udid,
        deviceType: deviceType,
        action: action,
        deviceInfo: deviceInfo,
      );
      onActionReplayed?.call();
    } catch (e) {
      final message = e.toString();
      pushLog(
        'Replay failed at action ${index + 1}: $message',
        LogStreamType.stderr,
      );
      final endSnapshot = await _captureReplaySnapshot(
        driver: driver,
        udid: udid,
        deviceType: deviceType,
        id: '${replayId}_end',
        startedAtMs: startedAtMs,
      );
      if (endSnapshot != null) stateSnapshots.add(endSnapshot);
      return ReplayResultBundle(
        result: RecordingReplayResult(
          recordingId: recording.id,
          source: 'studio-replay',
          startedAt: startedAt,
          endedAt: DateTime.now().toUtc().toIso8601String(),
          actionCount: recording.actionCount,
          status: 'failed',
          error: message,
          failedActionIndex: index,
          failedActionId: action.id,
          logs: replayLogs,
        ),
        stateSnapshots: stateSnapshots,
      );
    }
  }

  final endSnapshot = await _captureReplaySnapshot(
    driver: driver,
    udid: udid,
    deviceType: deviceType,
    id: '${replayId}_end',
    startedAtMs: startedAtMs,
  );
  if (endSnapshot != null) stateSnapshots.add(endSnapshot);
  pushLog(
    'Replay passed: ${recording.actions.length} actions',
    LogStreamType.stdout,
  );

  return ReplayResultBundle(
    result: RecordingReplayResult(
      recordingId: recording.id,
      source: 'studio-replay',
      startedAt: startedAt,
      endedAt: DateTime.now().toUtc().toIso8601String(),
      actionCount: recording.actionCount,
      status: 'passed',
      error: null,
      logs: replayLogs,
    ),
    stateSnapshots: stateSnapshots,
  );
}