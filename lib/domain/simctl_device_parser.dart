import 'dart:convert';

import '../models/models.dart';

/// Whether a simctl device entry should appear in the picker.
bool shouldListSimctlDevice(Map<String, dynamic> device) {
  if (device['state'] == 'Booted') return true;
  if (device['isAvailable'] == true) return true;
  // Some Xcode builds omit isAvailable for booted devices or mark them false
  // while the simulator is still running.
  if (device['isAvailable'] == null && device['availabilityError'] == null) {
    return true;
  }
  return false;
}

List<DeviceInfo> parseSimctlDevicesJson(String output) {
  try {
    final data = jsonDecode(output) as Map<String, dynamic>;
    final devicesMap = data['devices'] as Map<String, dynamic>? ?? {};
    final devices = <DeviceInfo>[];

    for (final entry in devicesMap.entries) {
      final runtime = entry.key;
      final deviceList = entry.value as List<dynamic>? ?? [];
      for (final raw in deviceList) {
        final device = raw as Map<String, dynamic>;
        if (!shouldListSimctlDevice(device)) continue;

        final udid = device['udid'] as String? ?? '';
        if (udid.isEmpty) continue;

        final runtimeName =
            runtime.replaceFirst('com.apple.CoreSimulator.SimRuntime.', '');
        final platform = runtimeName.contains('iOS') ? 'iOS' : runtimeName;

        devices.add(
          DeviceInfo(
            name: device['name'] as String? ?? 'Unknown',
            id: udid,
            platform: platform,
            type: DeviceType.iosSimulator,
            availability: device['isAvailable'] == true ? 'available' : 'listed',
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