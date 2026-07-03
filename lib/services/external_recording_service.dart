import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../models/enums.dart';
import '../models/hierarchy.dart';
import '../models/recording.dart' show ExternalRecordingActionPayload, RecordingActionType;
import 'bundled_resources.dart';
import 'settings_store.dart';
import 'simulator_driver_service.dart';
import 'simulator_window_bounds.dart';

const _swipeThresholdPx = 8.0;
const _longPressMs = 500;
const _mappingRefreshMs = 1500;

class _PointerGesture {
  _PointerGesture({
    required this.startX,
    required this.startY,
    required this.startTime,
    required this.lastX,
    required this.lastY,
  });

  final double startX;
  final double startY;
  final int startTime;
  double lastX;
  double lastY;
}

class _ActiveSession {
  _ActiveSession({
    required this.udid,
    required this.deviceName,
    required this.deviceType,
    required this.driver,
    required this.settingsStore,
  });

  final String udid;
  final String deviceName;
  final DeviceType deviceType;
  final SimulatorDriverService driver;
  final SettingsStore settingsStore;
  DeviceScreenMapping? mapping;
  _PointerGesture? pointer;
}

class ExternalRecordingService {
  ExternalRecordingService({
    SimulatorDriverService? driver,
    SettingsStore? settingsStore,
  })  : _driver = driver ?? SimulatorDriverService(settingsStore: settingsStore),
        _settingsStore = settingsStore ?? SettingsStore.instance;

  final SimulatorDriverService _driver;
  final SettingsStore _settingsStore;

  _ActiveSession? _session;
  Process? _monitorChild;
  Timer? _mappingTimer;
  String? _lastStatusError;

  final _actionController =
      StreamController<ExternalRecordingActionPayload>.broadcast();

  Stream<ExternalRecordingActionPayload> get actionStream =>
      _actionController.stream;

  ExternalRecordingStatus getStatus() {
    return ExternalRecordingStatus(
      active: _session != null,
      udid: _session?.udid,
      deviceName: _session?.deviceName,
      monitorRunning: _monitorChild != null,
      mappingReady: _session?.mapping != null,
      error: _lastStatusError,
    );
  }

  Future<ExternalRecordingStatus> start({
    required String udid,
    required String deviceName,
    required DeviceType deviceType,
  }) async {
    await stop();
    _lastStatusError = null;

    await _driver.ensureSession(udid: udid, deviceType: deviceType);
    await openSimulatorApp();

    _session = _ActiveSession(
      udid: udid,
      deviceName: deviceName,
      deviceType: deviceType,
      driver: _driver,
      settingsStore: _settingsStore,
    );

    await _refreshMapping();
    await _startMonitorProcess();
    _startMappingRefresh();

    return getStatus();
  }

  Future<void> stop() async {
    _mappingTimer?.cancel();
    _mappingTimer = null;
    _monitorChild?.kill(ProcessSignal.sigterm);
    _monitorChild = null;
    _session = null;
    _lastStatusError = null;
  }

  Future<void> _refreshMapping() async {
    final session = _session;
    if (session == null) return;

    try {
      final info = await session.driver.deviceInfo(
        udid: session.udid,
        deviceType: session.deviceType,
      );
      final mapping = buildDeviceScreenMapping(
        deviceName: session.deviceName,
        deviceWidthPx: info.widthPixels,
        deviceHeightPx: info.heightPixels,
      );
      if (mapping != null) {
        session.mapping = mapping;
        _lastStatusError = null;
      } else {
        session.mapping = null;
        _lastStatusError =
            'Could not locate Simulator window for the selected device.';
      }
    } catch (e) {
      session.mapping = null;
      _lastStatusError = 'Failed to resolve Simulator window mapping: $e';
    }
  }

  void _startMappingRefresh() {
    _mappingTimer?.cancel();
    _mappingTimer = Timer.periodic(
      const Duration(milliseconds: _mappingRefreshMs),
      (_) => unawaited(_refreshMapping()),
    );
  }

  Future<void> _startMonitorProcess() async {
    _monitorChild?.kill(ProcessSignal.sigterm);
    final binary = resolveBundledBinary(
      'simulator-input-monitor',
      'simulator-input-monitor',
    );
    if (binary == null) {
      throw Exception(
        'Simulator input monitor is not built. Run scripts/build-simulator-input-monitor.sh.',
      );
    }

    final process = await Process.start(
      binary.path,
      [],
      mode: ProcessStartMode.normal,
    );
    _monitorChild = process;

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) _handleMonitorLine(trimmed);
    });

    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) _lastStatusError = trimmed;
    });

    unawaited(process.exitCode.then((_) {
      if (_session != null) {
        _lastStatusError =
            'Simulator input monitor stopped unexpectedly.';
      }
      _monitorChild = null;
    }));
  }

  void _handleMonitorLine(String line) {
    Map<String, dynamic> event;
    try {
      event = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final session = _session;
    if (session == null) return;

    final kind = event['kind'] as String? ?? '';
    if (kind == 'error') {
      _lastStatusError =
          event['message'] as String? ?? 'Input monitor error';
      return;
    }

    final x = (event['x'] as num?)?.toDouble();
    final y = (event['y'] as num?)?.toDouble();
    final timestampMs = event['timestampMs'] as int?;
    if (x == null || y == null || timestampMs == null) return;

    switch (kind) {
      case 'mouseDown':
        session.pointer = _PointerGesture(
          startX: x,
          startY: y,
          startTime: timestampMs,
          lastX: x,
          lastY: y,
        );
      case 'mouseDrag':
        session.pointer?.lastX = x;
        session.pointer?.lastY = y;
      case 'mouseUp':
        final pointer = session.pointer;
        session.pointer = null;
        final mapping = session.mapping;
        if (pointer == null || mapping == null) return;
        final payload = _classifyGesture(mapping, pointer, x, y, timestampMs);
        if (payload != null) _actionController.add(payload);
      case 'scrollWheel':
        final mapping = session.mapping;
        if (mapping == null) return;
        final center = mapScreenPointToDevicePixels(mapping, x, y);
        if (center == null) return;
        const deltaY = 120.0;
        _actionController.add(
          ExternalRecordingActionPayload(
            type: RecordingActionType.swipe,
            x: center.$1,
            y: center.$2,
            toX: center.$1,
            toY: (center.$2 - deltaY).clamp(0, double.infinity),
            durationSec: 0.35,
          ),
        );
    }
  }

  ExternalRecordingActionPayload? _classifyGesture(
    DeviceScreenMapping mapping,
    _PointerGesture start,
    double endX,
    double endY,
    int endTime,
  ) {
    final startPoint =
        mapScreenPointToDevicePixels(mapping, start.startX, start.startY);
    if (startPoint == null) return null;

    final screenDist = math.sqrt(
      (endX - start.startX) * (endX - start.startX) +
          (endY - start.startY) * (endY - start.startY),
    );
    final elapsed = endTime - start.startTime;

    if (screenDist > _swipeThresholdPx) {
      final endPoint = mapScreenPointToDevicePixels(mapping, endX, endY);
      if (endPoint == null) return null;
      final durationSec = (elapsed / 1000.0).clamp(0.1, 1.5);
      return ExternalRecordingActionPayload(
        type: RecordingActionType.swipe,
        x: startPoint.$1,
        y: startPoint.$2,
        toX: endPoint.$1,
        toY: endPoint.$2,
        durationSec: durationSec,
      );
    }

    if (elapsed >= _longPressMs) {
      return ExternalRecordingActionPayload(
        type: RecordingActionType.longpress,
        x: startPoint.$1,
        y: startPoint.$2,
        durationSec: elapsed / 1000.0,
      );
    }

    return ExternalRecordingActionPayload(
      type: RecordingActionType.tap,
      x: startPoint.$1,
      y: startPoint.$2,
    );
  }
}