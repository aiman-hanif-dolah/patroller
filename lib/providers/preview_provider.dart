import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/preview_gestures.dart';
import '../models/models.dart';
import '../services/preview_stream_service.dart';
import '../services/simulator_driver_service.dart';
import 'facade_provider.dart';
import 'health_provider.dart';
import 'recording_provider.dart';
import 'runner_provider.dart';
import 'settings_provider.dart';

class PreviewState {
  const PreviewState({
    this.frame,
    this.readiness = PreviewReadiness.noDevice,
    this.activity = PreviewActivityLevel.idle,
    this.deviceInfo,
    this.error,
    this.lastInteractionAt,
    this.highlightFrame,
    this.metrics = const PreviewMetrics(),
    this.interactionFeedback,
  });

  final PreviewFrame? frame;
  final PreviewReadiness readiness;
  final PreviewActivityLevel activity;
  final XCTestDeviceInfo? deviceInfo;
  final String? error;
  final DateTime? lastInteractionAt;
  final ElementFrame? highlightFrame;
  final PreviewMetrics metrics;
  final PreviewInteractionFeedback? interactionFeedback;

  bool get isDriverReady =>
      readiness == PreviewReadiness.ready ||
      readiness == PreviewReadiness.stale ||
      (frame != null && error == null);

  bool get canInteract =>
      isDriverReady &&
      readiness != PreviewReadiness.noDevice &&
      readiness != PreviewReadiness.driverStarting &&
      readiness != PreviewReadiness.driverUnavailable;

  PreviewState copyWith({
    PreviewFrame? frame,
    PreviewReadiness? readiness,
    PreviewActivityLevel? activity,
    XCTestDeviceInfo? deviceInfo,
    String? error,
    DateTime? lastInteractionAt,
    ElementFrame? highlightFrame,
    PreviewMetrics? metrics,
    PreviewInteractionFeedback? interactionFeedback,
    bool clearFrame = false,
    bool clearError = false,
    bool clearHighlight = false,
    bool clearDeviceInfo = false,
    bool clearInteractionFeedback = false,
  }) {
    return PreviewState(
      frame: clearFrame ? null : (frame ?? this.frame),
      readiness: readiness ?? this.readiness,
      activity: activity ?? this.activity,
      deviceInfo: clearDeviceInfo ? null : (deviceInfo ?? this.deviceInfo),
      error: clearError ? null : (error ?? this.error),
      lastInteractionAt: lastInteractionAt ?? this.lastInteractionAt,
      highlightFrame:
          clearHighlight ? null : (highlightFrame ?? this.highlightFrame),
      metrics: metrics ?? this.metrics,
      interactionFeedback: clearInteractionFeedback
          ? null
          : (interactionFeedback ?? this.interactionFeedback),
    );
  }
}

class PreviewNotifier extends StateNotifier<PreviewState> {
  PreviewNotifier(
    this._ref, {
    PreviewState? initialState,
    @visibleForTesting bool disableSync = false,
  }) : super(initialState ?? const PreviewState()) {
    if (disableSync) return;
    _ref.listen(runnerProvider, (_, __) => _syncDevice());
    _ref.listen(settingsProvider, (_, __) => _syncDevice());
    _ref.listen(recordingProvider.select((s) => s.isRecording), (_, __) {
      _syncActivity();
    });
    Future.microtask(_syncDevice);
  }

  final Ref _ref;
  final _stream = PreviewStreamService();
  final _driver = SimulatorDriverService();
  Timer? _staleTimer;
  Timer? _feedbackTimer;
  String? _lastDeviceId;

  void _syncDevice() {
    final device = _ref.read(runnerProvider).selectedDevice;
    final settings = _ref.read(settingsProvider).settings;

    if (device == null ||
        device.state != DeviceState.booted ||
        device.type != DeviceType.iosSimulator) {
      _stream.stop();
      _staleTimer?.cancel();
      state = const PreviewState(readiness: PreviewReadiness.noDevice);
      return;
    }

    if (_lastDeviceId != null && _lastDeviceId != device.id) {
      _ref.read(healthProvider.notifier).markStale();
    }
    _lastDeviceId = device.id;

    _syncActivity();

    _stream.start(
      udid: device.id,
      deviceType: device.type,
      settings: settings,
      onFrame: _handleFrame,
      onError: _handleError,
      onReadiness: _handleReadiness,
      onMetrics: _handleMetrics,
    );

    unawaited(_loadDeviceInfo(device));
  }

  void _syncActivity() {
    final isRunning = _ref.read(runnerProvider).isRunning;
    final activity = _resolveActivity(isRunning);
    _stream.setActivity(activity);
    state = state.copyWith(activity: activity);
  }

  PreviewActivityLevel _resolveActivity(bool isRunning) {
    if (_ref.read(recordingProvider).isRecording) {
      return PreviewActivityLevel.interaction;
    }
    if (state.lastInteractionAt != null &&
        DateTime.now().difference(state.lastInteractionAt!) <
            const Duration(seconds: 2)) {
      return PreviewActivityLevel.interaction;
    }
    if (isRunning) return PreviewActivityLevel.active;
    return PreviewActivityLevel.idle;
  }

  Future<void> _loadDeviceInfo(DeviceInfo device) async {
    try {
      final info = await _ref
          .read(patrolStudioFacadeProvider)
          .simulator
          .deviceInfo(device.id, device.type);
      if (mounted) {
        state = state.copyWith(deviceInfo: info);
      }
    } catch (_) {}
  }

  void _handleMetrics({
    required int captureDurationMs,
    required bool emitted,
    required bool unchanged,
    required bool dropped,
    DateTime? lastSuccessfulFrameAt,
  }) {
    if (!mounted) return;
    var metrics = state.metrics.copyWith(
      lastCaptureDurationMs: captureDurationMs,
      lastSuccessfulFrameAt: lastSuccessfulFrameAt ?? state.metrics.lastSuccessfulFrameAt,
    );
    if (emitted) {
      metrics = metrics.copyWith(emittedFrames: metrics.emittedFrames + 1);
    }
    if (unchanged) {
      metrics = metrics.copyWith(unchangedFrames: metrics.unchangedFrames + 1);
    }
    if (dropped) {
      metrics = metrics.copyWith(droppedFrames: metrics.droppedFrames + 1);
    }
    state = state.copyWith(metrics: metrics);
  }

  void _handleFrame(PreviewFrame frame) {
    final previous = state.frame;
    if (previous?.fingerprint == frame.fingerprint) return;
    _staleTimer?.cancel();
    _staleTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && state.frame?.fingerprint == frame.fingerprint) {
        state = state.copyWith(readiness: PreviewReadiness.stale);
      }
    });
    state = state.copyWith(
      frame: frame,
      readiness: PreviewReadiness.ready,
      clearError: true,
    );
  }

  void _handleError(String error) {
    state = state.copyWith(error: error, readiness: PreviewReadiness.error);
  }

  void _handleReadiness(PreviewReadiness readiness) {
    if (readiness == PreviewReadiness.ready && state.frame != null) return;
    state = state.copyWith(readiness: readiness);
  }

  void setHighlight(ElementFrame? frame) {
    state = state.copyWith(highlightFrame: frame, clearHighlight: frame == null);
  }

  void burst() => _stream.burst();

  void _markInteraction() {
    state = state.copyWith(lastInteractionAt: DateTime.now());
    _stream.setActivity(PreviewActivityLevel.interaction);
    _stream.burst();
  }

  void _showFeedback(
    PreviewGestureKind kind, {
    Offset? position,
    Offset? endPosition,
  }) {
    _feedbackTimer?.cancel();
    state = state.copyWith(
      interactionFeedback: PreviewInteractionFeedback(
        kind: kind,
        at: DateTime.now(),
        position: position,
        endPosition: endPosition,
      ),
    );
    _feedbackTimer = Timer(const Duration(milliseconds: 550), () {
      if (mounted) {
        state = state.copyWith(clearInteractionFeedback: true);
      }
    });
  }

  bool _ensureInteractable() {
    if (!state.canInteract) return false;
    final device = _ref.read(runnerProvider).selectedDevice;
    return device != null && device.state == DeviceState.booted;
  }

  Future<void> performGesture(ClassifiedGesture gesture) async {
    if (!_ensureInteractable()) return;
    final device = _ref.read(runnerProvider).selectedDevice!;

    _markInteraction();

    switch (gesture.kind) {
      case PreviewGestureKind.tap:
        await _driver.tap(
          udid: device.id,
          x: gesture.start.dx,
          y: gesture.start.dy,
          deviceType: device.type,
        );
        _recordInteraction(RecordingActionType.tap, x: gesture.start.dx, y: gesture.start.dy);
        _showFeedback(PreviewGestureKind.tap, position: gesture.start);
      case PreviewGestureKind.longPress:
        final duration = gesture.durationSec ?? 1.0;
        await _driver.longPress(
          udid: device.id,
          x: gesture.start.dx,
          y: gesture.start.dy,
          durationSec: duration,
          deviceType: device.type,
        );
        _recordInteraction(
          RecordingActionType.longpress,
          x: gesture.start.dx,
          y: gesture.start.dy,
          durationSec: duration,
        );
        _showFeedback(PreviewGestureKind.longPress, position: gesture.start);
      case PreviewGestureKind.swipe:
      case PreviewGestureKind.scroll:
        final end = gesture.end ?? gesture.start;
        final duration = gesture.durationSec ?? 0.2;
        await _driver.swipe(
          udid: device.id,
          fromX: gesture.start.dx,
          fromY: gesture.start.dy,
          toX: end.dx,
          toY: end.dy,
          deviceType: device.type,
          duration: duration,
        );
        _recordInteraction(
          RecordingActionType.swipe,
          x: gesture.start.dx,
          y: gesture.start.dy,
          toX: end.dx,
          toY: end.dy,
          durationSec: duration,
        );
        _showFeedback(
          gesture.kind == PreviewGestureKind.scroll
              ? PreviewGestureKind.scroll
              : PreviewGestureKind.swipe,
          position: gesture.start,
          endPosition: end,
        );
    }
  }

  Future<void> tap(double x, double y, {double? durationSec}) async {
    if (!_ensureInteractable()) return;
    if (durationSec != null && durationSec > 0.3) {
      await performGesture(
        ClassifiedGesture(
          kind: PreviewGestureKind.longPress,
          start: Offset(x, y),
          durationSec: durationSec,
        ),
      );
    } else {
      await performGesture(
        ClassifiedGesture(
          kind: PreviewGestureKind.tap,
          start: Offset(x, y),
        ),
      );
    }
  }

  Future<void> swipe({
    required double fromX,
    required double fromY,
    required double toX,
    required double toY,
    double duration = 0.2,
  }) async {
    await performGesture(
      ClassifiedGesture(
        kind: PreviewGestureKind.swipe,
        start: Offset(fromX, fromY),
        end: Offset(toX, toY),
        durationSec: duration,
      ),
    );
  }

  Future<void> scrollAt({
    required double x,
    required double y,
    required double toX,
    required double toY,
    double duration = 0.25,
  }) async {
    await performGesture(
      ClassifiedGesture(
        kind: PreviewGestureKind.scroll,
        start: Offset(x, y),
        end: Offset(toX, toY),
        durationSec: duration,
      ),
    );
  }

  void _recordInteraction(
    RecordingActionType type, {
    double? x,
    double? y,
    double? toX,
    double? toY,
    double? durationSec,
  }) {
    if (!_ref.read(recordingProvider).isRecording) return;
    _ref.read(recordingProvider.notifier).recordAction(
          type,
          x: x,
          y: y,
          toX: toX,
          toY: toY,
          durationSec: durationSec,
        );
  }

  @override
  void dispose() {
    _stream.stop();
    _staleTimer?.cancel();
    _feedbackTimer?.cancel();
    super.dispose();
  }
}

final previewProvider =
    StateNotifierProvider<PreviewNotifier, PreviewState>(
  (ref) => PreviewNotifier(ref),
);