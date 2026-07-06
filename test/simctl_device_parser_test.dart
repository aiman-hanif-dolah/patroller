import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/domain/simctl_device_parser.dart';
import 'package:patroller/models/models.dart';

void main() {
  group('parseSimctlDevicesJson', () {
    test('includes booted simulator when isAvailable is false', () {
      const json = '''
{
  "devices": {
    "com.apple.CoreSimulator.SimRuntime.iOS-26-5": [
      {
        "state": "Booted",
        "isAvailable": false,
        "name": "iPhone 17 Pro Max",
        "udid": "ABC-123"
      }
    ]
  }
}
''';
      final devices = parseSimctlDevicesJson(json);
      expect(devices, hasLength(1));
      expect(devices.first.name, 'iPhone 17 Pro Max');
      expect(devices.first.state, DeviceState.booted);
    });

    test('skips unavailable shutdown simulator', () {
      const json = '''
{
  "devices": {
    "com.apple.CoreSimulator.SimRuntime.iOS-26-5": [
      {
        "state": "Shutdown",
        "isAvailable": false,
        "availabilityError": "runtime profile not found",
        "name": "Broken Sim",
        "udid": "BAD-1"
      }
    ]
  }
}
''';
      final devices = parseSimctlDevicesJson(json);
      expect(devices, isEmpty);
    });
  });
}