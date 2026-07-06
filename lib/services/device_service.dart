import 'dart:convert';
import 'dart:io';

import '../domain/simctl_device_parser.dart';
import '../models/models.dart';
import 'cli_env.dart';
import 'settings_store.dart';

class DeviceListResult {
  const DeviceListResult({
    required this.devices,
    this.scanError,
  });

  final List<DeviceInfo> devices;
  final String? scanError;
}

class DeviceService {
  DeviceService({SettingsStore? settingsStore})
      : _settingsStore = settingsStore ?? SettingsStore.instance;

  final SettingsStore _settingsStore;
  String? lastScanError;

  Future<List<DeviceInfo>> listDevices({bool enrichSimulators = true}) async {
    final result = await scanDevices(enrichSimulators: enrichSimulators);
    lastScanError = result.scanError;
    return result.devices;
  }

  Future<List<DeviceInfo>> refresh() => listDevices();

  Future<DeviceListResult> scanDevices({bool enrichSimulators = true}) async {
    await _settingsStore.getAsync();
    final errors = <String>[];

    List<DeviceInfo> simulators = [];
    if (Platform.isMacOS && enrichSimulators) {
      final simResult = await _listIosSimulators();
      simulators = simResult.devices;
      if (simResult.error != null) errors.add(simResult.error!);
    }

    final flutterResult = await _listFlutterDevices();
    final flutterDevices = flutterResult.devices;
    if (flutterResult.error != null) errors.add(flutterResult.error!);

    final merged = _mergeDeviceSources(
      simulators: simulators,
      flutterDevices: flutterDevices,
    );

    return DeviceListResult(
      devices: merged,
      scanError: errors.isEmpty ? null : errors.join(' · '),
    );
  }

  List<DeviceInfo> _mergeDeviceSources({
    required List<DeviceInfo> simulators,
    required List<DeviceInfo> flutterDevices,
  }) {
    if (simulators.isEmpty && flutterDevices.isEmpty) return [];

    if (simulators.isEmpty) {
      return flutterDevices
          .where((d) => d.type == DeviceType.iosSimulator || d.platform == 'ios')
          .toList();
    }

    final byId = {for (final s in simulators) s.id: s};
    for (final device in flutterDevices) {
      if (device.type != DeviceType.iosSimulator && device.platform != 'ios') {
        continue;
      }
      final existing = byId[device.id];
      if (existing != null) {
        byId[device.id] = existing.copyWith(
          name: device.name.isNotEmpty ? device.name : existing.name,
          state: existing.state ?? device.state,
        );
      } else {
        final byName = simulators.where((s) => s.name == device.name).firstOrNull;
        if (byName != null) {
          byId[byName.id] = byName.copyWith(
            state: byName.state ?? device.state,
          );
        }
      }
    }

    return byId.values.toList()
      ..sort((a, b) {
        final bootCmp = _bootOrder(b.state).compareTo(_bootOrder(a.state));
        if (bootCmp != 0) return bootCmp;
        return a.name.compareTo(b.name);
      });
  }

  int _bootOrder(DeviceState? state) {
    return switch (state) {
      DeviceState.booted => 2,
      DeviceState.shutdown => 1,
      _ => 0,
    };
  }

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

  Future<({List<DeviceInfo> devices, String? error})> _listFlutterDevices() async {
    final settings = _settingsStore.get();
    final flutter = resolveExecutable('flutter', configuredPath: settings.flutterPath);
    try {
      final result = await Process.run(
        flutter,
        ['devices', '--machine'],
        environment: developerToolEnv(),
      ).timeout(const Duration(seconds: 15));
      if (result.exitCode != 0) {
        final stderr = '${result.stderr}'.trim();
        return (
          devices: <DeviceInfo>[],
          error: stderr.isEmpty ? 'flutter devices failed' : stderr,
        );
      }
      return (
        devices: _parseFlutterDevices('${result.stdout}'),
        error: null,
      );
    } catch (e) {
      return (devices: <DeviceInfo>[], error: e.toString());
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

  Future<({List<DeviceInfo> devices, String? error})> _listIosSimulators() async {
    if (!Platform.isMacOS) return (devices: <DeviceInfo>[], error: null);
    final settings = _settingsStore.get();
    final xcrun = resolveExecutable('xcrun', configuredPath: settings.xcrunPath);
    try {
      final result = await Process.run(
        xcrun,
        ['simctl', 'list', 'devices', '--json'],
        environment: developerToolEnv(),
      ).timeout(const Duration(seconds: 10));
      if (result.exitCode != 0) {
        final stderr = '${result.stderr}'.trim();
        return (
          devices: <DeviceInfo>[],
          error: stderr.isEmpty
              ? 'xcrun simctl list failed (exit ${result.exitCode})'
              : stderr,
        );
      }
      final devices = parseSimctlDevicesJson('${result.stdout}');
      if (devices.isEmpty) {
        return (
          devices: devices,
          error: 'simctl returned no available iOS simulators',
        );
      }
      return (devices: devices, error: null);
    } catch (e) {
      return (devices: <DeviceInfo>[], error: e.toString());
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