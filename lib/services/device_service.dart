import 'dart:convert';
import 'dart:io';

import '../models/models.dart';
import 'cli_env.dart';
import 'settings_store.dart';

class DeviceService {
  DeviceService({SettingsStore? settingsStore})
      : _settingsStore = settingsStore ?? SettingsStore.instance;

  final SettingsStore _settingsStore;

  Future<List<DeviceInfo>> listDevices({bool enrichSimulators = true}) async {
    await _settingsStore.getAsync();
    final flutterDevices = await _listFlutterDevices();
    if (!enrichSimulators || !Platform.isMacOS) {
      return flutterDevices;
    }

    final simulators = await _listIosSimulators();
    final existingIds = flutterDevices.map((d) => d.id).toSet();

    final enriched = flutterDevices.map((device) {
      if (device.type == DeviceType.iosSimulator || device.platform == 'ios') {
        final sim = simulators.cast<DeviceInfo?>().firstWhere(
              (s) => s!.name == device.name || s.id == device.id,
              orElse: () => null,
            );
        if (sim != null) {
          return device.copyWith(state: sim.state, type: DeviceType.iosSimulator);
        }
      }
      return device;
    }).toList();

    final missingSims =
        simulators.where((s) => !existingIds.contains(s.id)).toList();
    return [...enriched, ...missingSims];
  }

  Future<List<DeviceInfo>> refresh() => listDevices();

  Future<String> bootSimulator(String udid) async {
    if (!Platform.isMacOS) {
      throw UnsupportedError('Simulator boot is only supported on macOS');
    }
    final settings = _settingsStore.get();
    final xcrun = resolveExecutable('xcrun', configuredPath: settings.xcrunPath);
    final result = await Process.run(
      xcrun,
      ['simctl', 'boot', udid],
      environment: developerToolEnv(),
    );
    if (result.exitCode != 0) {
      final stderr = '${result.stderr}'.trim();
      throw Exception(stderr.isEmpty ? 'Failed to boot simulator' : stderr);
    }
    final stdout = '${result.stdout}'.trim();
    return stdout.isEmpty ? 'Simulator booted successfully' : stdout;
  }

  Future<String> shutdownSimulator(String udid) async {
    if (!Platform.isMacOS) {
      throw UnsupportedError('Simulator shutdown is only supported on macOS');
    }
    final settings = _settingsStore.get();
    final xcrun = resolveExecutable('xcrun', configuredPath: settings.xcrunPath);
    final result = await Process.run(
      xcrun,
      ['simctl', 'shutdown', udid],
      environment: developerToolEnv(),
    );
    if (result.exitCode != 0) {
      final stderr = '${result.stderr}'.trim();
      throw Exception(stderr.isEmpty ? 'Failed to shutdown simulator' : stderr);
    }
    final stdout = '${result.stdout}'.trim();
    return stdout.isEmpty ? 'Simulator shutdown successfully' : stdout;
  }

  Future<List<DeviceInfo>> _listFlutterDevices() async {
    final settings = _settingsStore.get();
    final flutter = resolveExecutable('flutter', configuredPath: settings.flutterPath);
    try {
      final result = await Process.run(
        flutter,
        ['devices', '--machine'],
        environment: developerToolEnv(),
      ).timeout(const Duration(seconds: 15));
      return _parseFlutterDevices('${result.stdout}');
    } catch (e) {
      return _parseFlutterDevices(e.toString());
    }
  }

  List<DeviceInfo> _parseFlutterDevices(String output) {
    try {
      final devices = jsonDecode(output);
      if (devices is! List) return [];
      return devices.map((raw) {
        final d = raw as Map<String, dynamic>;
        final platform = _normalizePlatform(
          (d['platform'] ?? d['targetPlatform'] ?? '').toString(),
        );
        final emulator = d['emulator'] == true;
        final type = _mapDeviceType(
          platform,
          (d['type'] ?? d['category'] ?? '').toString(),
          emulator,
        );
        return DeviceInfo(
          name: (d['name'] ?? d['model'] ?? 'Unknown').toString(),
          id: (d['id'] ?? d['deviceId'] ?? '').toString(),
          platform: platform,
          type: type,
          availability: emulator
              ? 'emulator'
              : platform == 'ios'
                  ? 'device'
                  : 'unknown',
          rawLine: jsonEncode(d),
          state: type == DeviceType.iosSimulator
              ? (d['ephemeral'] == false
                  ? DeviceState.shutdown
                  : DeviceState.booted)
              : DeviceState.unknown,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<DeviceInfo>> _listIosSimulators() async {
    if (!Platform.isMacOS) return [];
    final settings = _settingsStore.get();
    final xcrun = resolveExecutable('xcrun', configuredPath: settings.xcrunPath);
    try {
      final result = await Process.run(
        xcrun,
        ['simctl', 'list', 'devices', '--json'],
        environment: developerToolEnv(),
      ).timeout(const Duration(seconds: 10));
      return _parseSimctlOutput('${result.stdout}');
    } catch (_) {
      return [];
    }
  }

  List<DeviceInfo> _parseSimctlOutput(String output) {
    try {
      final data = jsonDecode(output) as Map<String, dynamic>;
      final devicesMap = data['devices'] as Map<String, dynamic>? ?? {};
      final devices = <DeviceInfo>[];

      for (final entry in devicesMap.entries) {
        final runtime = entry.key;
        final deviceList = entry.value as List<dynamic>? ?? [];
        for (final raw in deviceList) {
          final device = raw as Map<String, dynamic>;
          if (device['isAvailable'] != true) continue;

          final runtimeName =
              runtime.replaceFirst('com.apple.CoreSimulator.SimRuntime.', '');
          final platform = runtimeName.contains('iOS') ? 'iOS' : runtimeName;

          devices.add(
            DeviceInfo(
              name: device['name'] as String? ?? 'Unknown',
              id: device['udid'] as String? ?? '',
              platform: platform,
              type: DeviceType.iosSimulator,
              availability: 'available',
              rawLine: jsonEncode(device),
              state: device['state'] == 'Booted'
                  ? DeviceState.booted
                  : DeviceState.shutdown,
            ),
          );
        }
      }
      return devices;
    } catch (_) {
      return [];
    }
  }

  String _normalizePlatform(String platform) {
    final lower = platform.toLowerCase();
    if (lower == 'ios' || lower.startsWith('ios-')) return 'ios';
    if (lower.startsWith('android')) return 'android';
    if (lower.contains('web-javascript')) return 'web';
    if (lower == 'darwin' || lower == 'macos') return 'macos';
    return platform.isEmpty ? 'unknown' : platform;
  }

  DeviceType _mapDeviceType(String platform, String category, bool emulator) {
    final lowerPlatform = platform.toLowerCase();
    final lowerCategory = category.toLowerCase();

    if (lowerPlatform == 'ios') {
      if (emulator ||
          lowerCategory == 'simulator' ||
          lowerCategory == 'emulator') {
        return DeviceType.iosSimulator;
      }
      return DeviceType.physicalIos;
    }
    if (lowerPlatform == 'android') {
      if (lowerCategory == 'emulator') return DeviceType.androidEmulator;
      return DeviceType.physicalAndroid;
    }
    if (lowerPlatform == 'web') return DeviceType.web;
    if (lowerPlatform == 'macos' ||
        lowerPlatform == 'linux' ||
        lowerPlatform == 'windows') {
      return DeviceType.desktop;
    }
    return DeviceType.unknown;
  }
}