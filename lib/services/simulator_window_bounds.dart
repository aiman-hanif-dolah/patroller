import 'dart:io';

class ScreenBounds {
  const ScreenBounds({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

class DeviceScreenMapping {
  const DeviceScreenMapping({
    required this.windowBounds,
    required this.screenBounds,
    required this.deviceWidthPx,
    required this.deviceHeightPx,
  });

  final ScreenBounds windowBounds;
  final ScreenBounds screenBounds;
  final int deviceWidthPx;
  final int deviceHeightPx;
}

const _simulatorProcess = 'Simulator';

ScreenBounds? findSimulatorWindowBounds({String? deviceName}) {
  if (!Platform.isMacOS) return null;

  final nameFilter = deviceName != null
      ? 'whose name contains "${deviceName.replaceAll('"', r'\"')}"'
      : '';

  final script = '''
tell application "System Events"
  if not (exists process "$_simulatorProcess") then return "missing"
  tell process "$_simulatorProcess"
    set targetWindows to every window $nameFilter
    if (count of targetWindows) is 0 then
      if (count of windows) is 0 then return "missing"
      set targetWindow to window 1
    else
      set targetWindow to item 1 of targetWindows
    end if
    set winPos to position of targetWindow
    set winSize to size of targetWindow
    return (item 1 of winPos as text) & "," & (item 2 of winPos as text) & "," & (item 1 of winSize as text) & "," & (item 2 of winSize as text)
  end tell
end tell''';

  try {
    final output = Process.runSync('osascript', ['-e', script]);
    if (output.exitCode != 0) return null;
    final text = '${output.stdout}'.trim();
    if (text == 'missing') return null;
    final parts = text.split(',').map((p) => double.tryParse(p.trim())).toList();
    if (parts.length != 4 || parts.any((p) => p == null)) return null;
    final width = parts[2]!;
    final height = parts[3]!;
    if (width <= 0 || height <= 0) return null;
    return ScreenBounds(x: parts[0]!, y: parts[1]!, width: width, height: height);
  } catch (_) {
    return null;
  }
}

ScreenBounds computeDeviceScreenBounds(
  ScreenBounds windowBounds,
  int deviceWidthPx,
  int deviceHeightPx,
) {
  final deviceAspect = deviceWidthPx / deviceHeightPx;
  final windowAspect = windowBounds.width / windowBounds.height;

  late final double innerWidth;
  late final double innerHeight;
  if (windowAspect > deviceAspect) {
    innerHeight = windowBounds.height;
    innerWidth = innerHeight * deviceAspect;
  } else {
    innerWidth = windowBounds.width;
    innerHeight = innerWidth / deviceAspect;
  }

  return ScreenBounds(
    x: windowBounds.x + (windowBounds.width - innerWidth) / 2,
    y: windowBounds.y + (windowBounds.height - innerHeight) / 2,
    width: innerWidth,
    height: innerHeight,
  );
}

DeviceScreenMapping? buildDeviceScreenMapping({
  required String deviceName,
  required int deviceWidthPx,
  required int deviceHeightPx,
}) {
  final windowBounds = findSimulatorWindowBounds(deviceName: deviceName);
  if (windowBounds == null) return null;
  final screenBounds = computeDeviceScreenBounds(
    windowBounds,
    deviceWidthPx,
    deviceHeightPx,
  );
  return DeviceScreenMapping(
    windowBounds: windowBounds,
    screenBounds: screenBounds,
    deviceWidthPx: deviceWidthPx,
    deviceHeightPx: deviceHeightPx,
  );
}

(double, double)? mapScreenPointToDevicePixels(
  DeviceScreenMapping mapping,
  double screenX,
  double screenY,
) {
  final sb = mapping.screenBounds;
  if (screenX < sb.x ||
      screenY < sb.y ||
      screenX > sb.x + sb.width ||
      screenY > sb.y + sb.height) {
    return null;
  }
  final xPx =
      ((screenX - sb.x) / sb.width * mapping.deviceWidthPx).roundToDouble();
  final yPx =
      ((screenY - sb.y) / sb.height * mapping.deviceHeightPx).roundToDouble();
  return (
    xPx.clamp(0, mapping.deviceWidthPx - 1.0),
    yPx.clamp(0, mapping.deviceHeightPx - 1.0),
  );
}

Future<void> openSimulatorApp() async {
  if (!Platform.isMacOS) return;
  final result = await Process.run('open', ['-a', 'Simulator']);
  if (result.exitCode != 0) {
    throw Exception('Failed to open Simulator app');
  }
  await Future<void>.delayed(const Duration(milliseconds: 500));
}