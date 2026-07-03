import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

  final PreviewFrame? frame;
  final PreviewReadiness readiness;
  final PreviewActivityLevel activity;
  final XCTestDeviceInfo? deviceInfo;
  final String? error;
  final DateTime? lastInteractionAt;
  final ElementFrame? highlightFrame;

  bool get isDriverReady =>
      readiness == PreviewReadiness.ready ||
      readiness == PreviewReadiness.stale ||
      (frame != null && error == null);

  PreviewState copyWith({
    PreviewFrame? frame,
    PreviewReadiness? readiness,
    PreviewActivityLevel? activity,
    XCTestDeviceInfo? deviceInfo,
    String? error,
    DateTime? lastInteractionAt,
    ElementFrame? highlightFrame,
    bool clearFrame = false,
    bool clearError = false,
    bool clearHighlight = false,
    bool clearDeviceInfo = false,
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
    );
  }
}

class PreviewNotifier extends StateNotifier<PreviewState> {
  PreviewNotifier(this._ref) : super(const PreviewState()) {
    _ref.listen(runnerProvider, (_, __) => _syncDevice());
    _ref.listen(settingsProvider, (_, __) => _syncDevice());
    Future.microtask(_syncDevice);
  }

  final Ref _ref;
  final _stream = PreviewStreamService();
  final _driver = SimulatorDriverService();
  Timer? _staleTimer;
  String? _lastDeviceId;

  void _syncDevice() {
    final device = _ref.read(runnerProvider).selectedDevice;
    final settings = _ref.read(settingsProvider).settings;
    final isRunning = _ref.read(runnerProvider).isRunning;

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

    final activity = _resolveActivity(isRunning);
    _stream.setActivity(activity);
    state = state.copyWith(activity: activity);

    _stream.start(
      udid: device.id,
      deviceType: device.type,
      settings: settings,
      onFrame: _handleFrame,
      onError: _handleError,
      onReadiness: _handleReadiness,
    );

    unawaited(_loadDeviceInfo(device));
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

  Future<void> tap(double x, double y, {double? durationSec}) async {
    final device = _ref.read(runnerProvider).selectedDevice;
    if (device == null) return;
    _markInteraction();

    if (durationSec != null && durationSec > 0.3) {
      await _driver.longPress(
        udid: device.id,
        x: x,
        y: y,
        durationSec: durationSec,
        deviceType: device.type,
      );
      _recordInteraction(RecordingActionType.longpress, x: x, y: y, durationSec: durationSec);
    } else {
      await _driver.tap(
        udid: device.id,
        x: x,
        y: y,
        deviceType: device.type,
        duration: durationSec,
      );
      _recordInteraction(RecordingActionType.tap, x: x, y: y);
    }
  }

  Future<void> swipe({
    required double fromX,
    required double fromY,
    required double toX,
    required double toY,
    double duration = 0.2,
  }) async {
    final device = _ref.read(runnerProvider).selectedDevice;
    if (device == null) return;
    _markInteraction();

    await _driver.swipe(
      udid: device.id,
      fromX: fromX,
      fromY: fromY,
      toX: toX,
      toY: toY,
      deviceType: device.type,
      duration: duration,
    );

    final scale = _pixelScale();
    _recordInteraction(
      RecordingActionType.swipe,
      x: fromX * scale,
      y: fromY * scale,
      toX: toX * scale,
      toY: toY * scale,
    );
  }

  double _pixelScale() {
    final info = state.deviceInfo;
    if (info == null || info.widthPoints == 0) return 1;
    return info.widthPixels / info.widthPoints;
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
    final scale = _pixelScale();
    _ref.read(recordingProvider.notifier).recordAction(
          type,
          x: x != null ? x * scale : null,
          y: y != null ? y * scale : null,
          toX: toX,
          toY: toY,
          durationSec: durationSec,
        );
  }

  @override
  void dispose() {
    _stream.stop();
    _staleTimer?.cancel();
    super.dispose();
  }
}

final previewProvider =
    StateNotifierProvider<PreviewNotifier, PreviewState>(
  (ref) => PreviewNotifier(ref),
);