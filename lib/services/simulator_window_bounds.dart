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
    required this.deviceWidthPoints,
    required this.deviceHeightPoints,
  });

  final ScreenBounds windowBounds;
  final ScreenBounds screenBounds;
  final int deviceWidthPx;
  final int deviceHeightPx;
  final int deviceWidthPoints;
  final int deviceHeightPoints;
}

const _simulatorProcess = 'Simulator';

ScreenBounds? findSimulatorWindowBounds({String? deviceName}) {
  if (!Platform.isMacOS) return null;

  final nameFilter = deviceName != null ? deviceName.replaceAll('"', r'\"') : '';

  final script = '''
tell application "System Events"
  if not (exists process "$_simulatorProcess") then return "missing"
  tell process "$_simulatorProcess"
    set winList to every window
    if (count of winList) is 0 then return "missing"
    set targetWindow to item 1 of winList
    if "$nameFilter" is not "" then
      repeat with w in winList
        try
          if (name of w) contains "$nameFilter" then
            set targetWindow to w
            exit repeat
          end if
        end try
      end repeat
    end if
    
    try
      set grpList to every group of targetWindow
      if (count of grpList) > 0 then
        set targetElem to item 1 of grpList
        set winPos to position of targetElem
        set winSize to size of targetElem
        return (item 1 of winPos as text) & "," & (item 2 of winPos as text) & "," & (item 1 of winSize as text) & "," & (item 2 of winSize as text)
      end if
    end try

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
  required int deviceWidthPoints,
  required int deviceHeightPoints,
  ScreenBounds? windowBounds,
}) {
  final bounds = windowBounds ?? findSimulatorWindowBounds(deviceName: deviceName);
  if (bounds == null) return null;
  final screenBounds = computeDeviceScreenBounds(
    bounds,
    deviceWidthPoints,
    deviceHeightPoints,
  );
  return DeviceScreenMapping(
    windowBounds: bounds,
    screenBounds: screenBounds,
    deviceWidthPx: deviceWidthPx,
    deviceHeightPx: deviceHeightPx,
    deviceWidthPoints: deviceWidthPoints,
    deviceHeightPoints: deviceHeightPoints,
  );
}

(double, double)? mapScreenPointToDevicePoints(
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
  final xPt =
      ((screenX - sb.x) / sb.width * mapping.deviceWidthPoints).roundToDouble();
  final yPt =
      ((screenY - sb.y) / sb.height * mapping.deviceHeightPoints).roundToDouble();
  return (
    xPt.clamp(0, mapping.deviceWidthPoints - 1.0),
    yPt.clamp(0, mapping.deviceHeightPoints - 1.0),
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