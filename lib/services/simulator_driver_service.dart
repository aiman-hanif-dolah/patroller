import 'dart:io';

import '../domain/simulator_user_apps.dart';
import '../models/enums.dart';
import '../models/hierarchy.dart';
import 'cli_env.dart';
import 'settings_store.dart';
import 'xctest_client.dart';
import 'xctest_installer.dart';

const _driverRunnerBundleId = 'studio.patrol.PatrolSimulatorDriverUITests.xctrunner';

class SimulatorDriverService {
  SimulatorDriverService({SettingsStore? settingsStore})
      : _settingsStore = settingsStore ?? SettingsStore.instance;

  final SettingsStore _settingsStore;

  DriverStatus getDriverStatus() => XCTestInstaller.instance.getDriverStatus();

  Future<DriverStatus> repairDriver({
    required String udid,
    required DeviceType deviceType,
  }) async {
    final settings = _settingsStore.get();
    await XCTestInstaller.instance.repairSession(
      udid: udid,
      deviceType: deviceType,
      port: settings.xctestRunnerPort,
      xcrunPath: settings.xcrunPath,
    );
    return getDriverStatus();
  }

  Future<void> ensureSession({
    required String udid,
    required DeviceType deviceType,
  }) async {
    final settings = _settingsStore.get();
    await XCTestInstaller.instance.ensureSession(
      udid: udid,
      deviceType: deviceType,
      port: settings.xctestRunnerPort,
      xcrunPath: settings.xcrunPath,
    );
  }

  XCTestClient? _client() {
    final port = XCTestInstaller.instance.getActivePort();
    if (port == null) return null;
    return XCTestClient(port);
  }

  Future<List<int>> screenshot({
    required String udid,
    required DeviceType deviceType,
    bool compressed = false,
  }) async {
    await ensureSession(udid: udid, deviceType: deviceType);
    final client = _client();
    if (client == null) {
      throw Exception('Simulator driver is not ready');
    }
    return client.screenshot(compressed: compressed);
  }

  Future<bool> isScreenStatic({
    required String udid,
    required DeviceType deviceType,
  }) async {
    await ensureSession(udid: udid, deviceType: deviceType);
    final client = _client();
    if (client == null) return true;
    return client.isScreenStatic();
  }

  Future<XCTestDeviceInfo> deviceInfo({
    required String udid,
    required DeviceType deviceType,
  }) async {
    await ensureSession(udid: udid, deviceType: deviceType);
    final client = _client();
    if (client == null) {
      return const XCTestDeviceInfo(
        widthPixels: 1170,
        heightPixels: 2532,
        widthPoints: 390,
        heightPoints: 844,
      );
    }
    return client.deviceInfo();
  }

  Future<void> tap({
    required String udid,
    required double x,
    required double y,
    required DeviceType deviceType,
    double? duration,
  }) async {
    await ensureSession(udid: udid, deviceType: deviceType);
    final client = _client();
    if (client == null) return;
    await client.tap(x, y, duration: duration);
  }

  Future<void> tapElement({
    required String udid,
    required ElementFrame frame,
    required DeviceType deviceType,
  }) async {
    final cx = frame.x + frame.width / 2;
    final cy = frame.y + frame.height / 2;
    await tap(udid: udid, x: cx, y: cy, deviceType: deviceType);
  }

  Future<void> longPress({
    required String udid,
    required double x,
    required double y,
    required double durationSec,
    required DeviceType deviceType,
  }) async {
    await tap(
      udid: udid,
      x: x,
      y: y,
      deviceType: deviceType,
      duration: durationSec,
    );
  }

  Future<void> swipe({
    required String udid,
    required double fromX,
    required double fromY,
    required double toX,
    required double toY,
    required DeviceType deviceType,
    double? duration,
  }) async {
    await ensureSession(udid: udid, deviceType: deviceType);
    final client = _client();
    if (client == null) return;
    await client.swipe(
      fromX: fromX,
      fromY: fromY,
      toX: toX,
      toY: toY,
      duration: duration ?? 0.2,
    );
  }

  Future<void> inputText({
    required String udid,
    required String text,
    required DeviceType deviceType,
  }) async {
    await ensureSession(udid: udid, deviceType: deviceType);
    final client = _client();
    if (client == null) return;
    await client.inputText(text);
  }

  Future<void> pressKey({
    required String udid,
    required String key,
    required DeviceType deviceType,
  }) async {
    await ensureSession(udid: udid, deviceType: deviceType);
    final client = _client();
    if (client == null) return;
    await client.pressKey(key);
  }

  Future<List<String>> listUserBundleIds(String udid) async {
    if (!Platform.isMacOS) return const [];
    final settings = _settingsStore.get();
    final output = await Process.run(
      resolveExecutable('xcrun', configuredPath: settings.xcrunPath),
      ['simctl', 'listapps', udid],
      environment: developerToolEnv(),
    );
    if (output.exitCode != 0) return const [];
    return parseSimulatorUserBundleIds(
      '${output.stdout}',
      excludeBundleId: _driverRunnerBundleId,
    );
  }

  Future<String?> runningApp({
    required String udid,
    required DeviceType deviceType,
    List<String> candidateAppIds = const [],
  }) async {
    await ensureSession(udid: udid, deviceType: deviceType);
    final client = _client();
    if (client == null) return null;
    final candidates = candidateAppIds.isNotEmpty
        ? candidateAppIds
        : await listUserBundleIds(udid);
    if (candidates.isEmpty) return null;
    return client.runningApp(candidateAppIds: candidates);
  }

  Future<HierarchyNode> viewHierarchy({
    required String udid,
    required DeviceType deviceType,
    String? appId,
    List<String> candidateAppIds = const [],
  }) async {
    await ensureSession(udid: udid, deviceType: deviceType);
    final client = _client();
    if (client == null) {
      return const HierarchyNode(type: 'stub', children: []);
    }

    final candidates = appId != null
        ? [appId]
        : (candidateAppIds.isNotEmpty
            ? candidateAppIds
            : await listUserBundleIds(udid));
    if (candidates.isEmpty) {
      return const HierarchyNode(type: 'stub', children: []);
    }

    final resolvedAppId = appId ?? await client.runningApp(
      candidateAppIds: candidates,
    );
    if (resolvedAppId == null) {
      return const HierarchyNode(type: 'stub', children: []);
    }

    return client.viewHierarchy(
      appId: resolvedAppId,
      candidateAppIds: candidates,
    );
  }

  void stopSession([String? udid]) {
    XCTestInstaller.instance.stopSession(udid);
  }
}