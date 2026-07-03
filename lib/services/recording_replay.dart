import 'dart:async';
import 'dart:convert';

import '../domain/state_snapshot.dart';
import '../models/enums.dart';
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

Future<void> _replayAction({
  required SimulatorDriverService driver,
  required String udid,
  required DeviceType deviceType,
  required RecordingAction action,
}) async {
  switch (action.type) {
    case RecordingActionType.tap:
      await driver.tap(
        udid: udid,
        x: action.x ?? 0,
        y: action.y ?? 0,
        deviceType: deviceType,
      );
    case RecordingActionType.longpress:
      await driver.longPress(
        udid: udid,
        x: action.x ?? 0,
        y: action.y ?? 0,
        durationSec: action.durationSec ?? 0.6,
        deviceType: deviceType,
      );
    case RecordingActionType.swipe:
      await driver.swipe(
        udid: udid,
        fromX: action.x ?? 0,
        fromY: action.y ?? 0,
        toX: action.toX ?? action.x ?? 0,
        toY: action.toY ?? action.y ?? 0,
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

  await driver.deviceInfo(udid: udid, deviceType: deviceType);
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
      );
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