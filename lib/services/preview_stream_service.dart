import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/models.dart';
import 'simulator_driver_service.dart';

const _refreshBurstDelaysMs = [20, 100];
const _staticTicksBeforeSlowdown = 3;
const _fingerprintChunkSize = 4096;

/// Stable chunked FNV-1a hash over the full screenshot buffer.
String fingerprintBuffer(Uint8List buffer) {
  if (buffer.isEmpty) return '0';
  var hash = 2166136261;
  for (var offset = 0; offset < buffer.length; offset += _fingerprintChunkSize) {
    final end = math.min(offset + _fingerprintChunkSize, buffer.length);
    for (var i = offset; i < end; i++) {
      hash ^= buffer[i];
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }
  }
  return '${buffer.length.toRadixString(16)}-${hash.toRadixString(16)}';
}

typedef PreviewMetricsCallback = void Function({
  required int captureDurationMs,
  required bool emitted,
  required bool unchanged,
  required bool dropped,
  DateTime? lastSuccessfulFrameAt,
});

class PreviewStreamService {
  PreviewStreamService({SimulatorDriverService? driver})
      : _driver = driver ?? SimulatorDriverService();

  final SimulatorDriverService _driver;

  _PreviewSession? _activeSession;
  PreviewActivityLevel _requestedActivity = PreviewActivityLevel.active;

  bool get isActive => _activeSession != null && !_activeSession!.cancelled;

  bool isActiveFor(String udid) =>
      isActive && _activeSession!.udid == udid;

  void start({
    required String udid,
    required DeviceType deviceType,
    required AppSettings settings,
    required void Function(PreviewFrame frame) onFrame,
    required void Function(String error) onError,
    required void Function(PreviewReadiness readiness) onReadiness,
    PreviewMetricsCallback? onMetrics,
  }) {
    if (_activeSession != null &&
        !_activeSession!.cancelled &&
        _activeSession!.udid == udid &&
        _activeSession!.deviceType == deviceType) {
      _activeSession!.activity = _requestedActivity;
      _activeSession!.settings = settings;
      _activeSession!.onMetrics = onMetrics;
      if (!_activeSession!.captureInFlight && _activeSession!.loopTimer == null) {
        unawaited(_runPreviewTick(_activeSession!));
      }
      return;
    }

    stop();
    final session = _PreviewSession(
      udid: udid,
      deviceType: deviceType,
      settings: settings,
      activity: _requestedActivity,
      onFrame: onFrame,
      onError: onError,
      onReadiness: onReadiness,
      onMetrics: onMetrics,
    );
    _activeSession = session;
    unawaited(_runPreviewTick(session));
  }

  void setActivity(PreviewActivityLevel level) {
    _requestedActivity = level;
    final session = _activeSession;
    if (session == null || session.cancelled) return;
    if (session.activity == level) return;
    session.activity = level;
    session.unchangedTicks = 0;
    session.loopTimer?.cancel();
    session.loopTimer = null;
    unawaited(_runPreviewTick(session));
  }

  void burst() {
    final session = _activeSession;
    if (session == null || session.cancelled) return;
    session.lastFingerprint = null;
    session.unchangedTicks = 0;
    for (final delay in _refreshBurstDelaysMs) {
      late final Timer timer;
      timer = Timer(Duration(milliseconds: delay), () {
        session.burstTimers.remove(timer);
        if (session.cancelled) return;
        unawaited(_scheduleBurstCapture(session));
      });
      session.burstTimers.add(timer);
    }
  }

  Future<void> _scheduleBurstCapture(_PreviewSession session) async {
    if (session.captureInFlight) {
      session.burstQueued = true;
      return;
    }
    await _captureOnce(session);
  }

  void stop() {
    final session = _activeSession;
    if (session == null) return;
    session.cancelled = true;
    session.loopTimer?.cancel();
    session.loopTimer = null;
    for (final timer in session.burstTimers) {
      timer.cancel();
    }
    session.burstTimers.clear();
    _activeSession = null;
  }

  int _intervalForActivity(_PreviewSession session) {
    final settings = session.settings;
    switch (session.activity) {
      case PreviewActivityLevel.interaction:
        return settings.previewInteractionPollIntervalMs;
      case PreviewActivityLevel.active:
        return settings.previewActivePollIntervalMs;
      case PreviewActivityLevel.idle:
        return settings.previewIdlePollIntervalMs;
    }
  }

  int _currentPollIntervalMs(_PreviewSession session) {
    final base = _intervalForActivity(session);
    if (session.activity == PreviewActivityLevel.active &&
        session.unchangedTicks >= _staticTicksBeforeSlowdown) {
      return math.max(base, session.settings.previewIdlePollIntervalMs);
    }
    return base;
  }

  Future<void> _captureOnce(_PreviewSession session) async {
    if (session.captureInFlight) {
      session.captureQueued = true;
      session.onMetrics?.call(
        captureDurationMs: 0,
        emitted: false,
        unchanged: false,
        dropped: true,
        lastSuccessfulFrameAt: session.lastSuccessfulFrameAt,
      );
      return;
    }
    session.captureInFlight = true;
    try {
      final driverStatus = _driver.getDriverStatus();
      if (driverStatus.state == DriverState.starting) {
        session.onReadiness(PreviewReadiness.driverStarting);
        return;
      }
      if (driverStatus.state != DriverState.ready) {
        session.onReadiness(PreviewReadiness.driverUnavailable);
        return;
      }

      session.onReadiness(PreviewReadiness.loading);
      final captureStartedAt = DateTime.now();
      final bytes = await _driver.screenshot(
        udid: session.udid,
        deviceType: session.deviceType,
        compressed: true,
      );
      final captureDurationMs =
          DateTime.now().difference(captureStartedAt).inMilliseconds;
      if (session.cancelled) return;

      final fingerprint = fingerprintBuffer(Uint8List.fromList(bytes));
      if (fingerprint == session.lastFingerprint) {
        session.unchangedTicks += 1;
        session.onReadiness(PreviewReadiness.ready);
        session.onMetrics?.call(
          captureDurationMs: captureDurationMs,
          emitted: false,
          unchanged: true,
          dropped: false,
          lastSuccessfulFrameAt: session.lastSuccessfulFrameAt,
        );
        return;
      }

      session.unchangedTicks = 0;
      session.lastFingerprint = fingerprint;
      session.lastSuccessfulFrameAt = DateTime.now();
      session.onFrame(
        PreviewFrame(
          bytes: Uint8List.fromList(bytes),
          fingerprint: fingerprint,
          capturedAt: session.lastSuccessfulFrameAt!,
          captureDurationMs: captureDurationMs,
        ),
      );
      session.onReadiness(PreviewReadiness.ready);
      session.onMetrics?.call(
        captureDurationMs: captureDurationMs,
        emitted: true,
        unchanged: false,
        dropped: false,
        lastSuccessfulFrameAt: session.lastSuccessfulFrameAt,
      );
    } catch (e) {
      if (!session.cancelled) {
        session.onError(e.toString().replaceFirst('Exception: ', ''));
        session.onReadiness(PreviewReadiness.error);
      }
    } finally {
      session.captureInFlight = false;
      if (session.burstQueued && !session.cancelled) {
        session.burstQueued = false;
        unawaited(_captureOnce(session));
      } else if (session.captureQueued && !session.cancelled) {
        session.captureQueued = false;
        unawaited(_captureOnce(session));
      }
    }
  }

  void _scheduleNext(_PreviewSession session, int delayMs) {
    if (session.cancelled) return;
    session.loopTimer?.cancel();
    session.loopTimer = Timer(Duration(milliseconds: delayMs), () {
      session.loopTimer = null;
      unawaited(_runPreviewTick(session));
    });
  }

  Future<void> _runPreviewTick(_PreviewSession session) async {
    if (session.cancelled) return;
    final startedAt = DateTime.now();
    final interval = _currentPollIntervalMs(session);
    try {
      await _captureOnce(session);
    } catch (_) {
      // Retry on next tick.
    }
    if (session.cancelled) return;
    final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
    final delay = elapsed >= interval ? 0 : interval - elapsed;
    _scheduleNext(session, delay);
  }
}

class _PreviewSession {
  _PreviewSession({
    required this.udid,
    required this.deviceType,
    required this.settings,
    required this.activity,
    required this.onFrame,
    required this.onError,
    required this.onReadiness,
    this.onMetrics,
  });

  final String udid;
  final DeviceType deviceType;
  AppSettings settings;
  PreviewActivityLevel activity;
  final void Function(PreviewFrame frame) onFrame;
  final void Function(String error) onError;
  final void Function(PreviewReadiness readiness) onReadiness;
  PreviewMetricsCallback? onMetrics;

  bool cancelled = false;
  String? lastFingerprint;
  int unchangedTicks = 0;
  bool captureInFlight = false;
  bool captureQueued = false;
  bool burstQueued = false;
  DateTime? lastSuccessfulFrameAt;
  Timer? loopTimer;
  final burstTimers = <Timer>{};
}