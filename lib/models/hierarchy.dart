enum DriverState {
  idle,
  starting,
  ready,
  restarting,
  error,
  stopped;

  String toJson() => name;

  static DriverState fromJson(String value) =>
      DriverState.values.firstWhere((e) => e.name == value, orElse: () => DriverState.idle);
}

class DriverStatus {
  const DriverStatus({
    required this.state,
    this.port,
    this.udid,
    this.error,
    this.logTail,
  });

  final DriverState state;
  final int? port;
  final String? udid;
  final String? error;
  final String? logTail;

  factory DriverStatus.idle() => const DriverStatus(state: DriverState.idle);

  Map<String, dynamic> toJson() => {
        'state': state.toJson(),
        if (port != null) 'port': port,
        if (udid != null) 'udid': udid,
        if (error != null) 'error': error,
        if (logTail != null) 'logTail': logTail,
      };

  factory DriverStatus.fromJson(Map<String, dynamic> json) => DriverStatus(
        state: DriverState.fromJson(json['state'] as String? ?? 'idle'),
        port: json['port'] as int?,
        udid: json['udid'] as String?,
        error: json['error'] as String?,
        logTail: json['logTail'] as String?,
      );
}

class XCTestDeviceInfo {
  const XCTestDeviceInfo({
    required this.widthPixels,
    required this.heightPixels,
    required this.widthPoints,
    required this.heightPoints,
  });

  final int widthPixels;
  final int heightPixels;
  final int widthPoints;
  final int heightPoints;

  factory XCTestDeviceInfo.fromJson(Map<String, dynamic> json) {
    return XCTestDeviceInfo(
      widthPixels: json['widthPixels'] as int? ?? 1170,
      heightPixels: json['heightPixels'] as int? ?? 2532,
      widthPoints: json['widthPoints'] as int? ?? 390,
      heightPoints: json['heightPoints'] as int? ?? 844,
    );
  }
}

class ElementFrame {
  const ElementFrame({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };

  factory ElementFrame.fromJson(Map<String, dynamic> json) {
    return ElementFrame(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 0,
      height: (json['height'] as num?)?.toDouble() ?? 0,
    );
  }
}

class HierarchyNode {
  const HierarchyNode({
    this.type,
    this.label,
    this.accessibilityId,
    this.value,
    this.enabled,
    this.visible,
    this.frame,
    this.children,
  });

  final String? type;
  final String? label;
  final String? accessibilityId;
  final String? value;
  final bool? enabled;
  final bool? visible;
  final ElementFrame? frame;
  final List<HierarchyNode>? children;

  Map<String, dynamic> toJson() => {
        if (type != null) 'type': type,
        if (label != null) 'label': label,
        if (accessibilityId != null) 'accessibilityId': accessibilityId,
        if (value != null) 'value': value,
        if (enabled != null) 'enabled': enabled,
        if (visible != null) 'visible': visible,
        if (frame != null) 'frame': frame!.toJson(),
        if (children != null) 'children': children!.map((c) => c.toJson()).toList(),
      };

  factory HierarchyNode.fromJson(Map<String, dynamic> json) {
    return HierarchyNode(
      type: json['type'] as String?,
      label: json['label'] as String?,
      accessibilityId: json['accessibilityId'] as String?,
      value: json['value'] as String?,
      enabled: json['enabled'] as bool?,
      visible: json['visible'] as bool?,
      frame: json['frame'] != null
          ? ElementFrame.fromJson(json['frame'] as Map<String, dynamic>)
          : null,
      children: (json['children'] as List<dynamic>?)
          ?.map((c) => HierarchyNode.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ExternalRecordingStatus {
  const ExternalRecordingStatus({
    required this.active,
    this.udid,
    this.deviceName,
    required this.monitorRunning,
    required this.mappingReady,
    this.error,
  });

  final bool active;
  final String? udid;
  final String? deviceName;
  final bool monitorRunning;
  final bool mappingReady;
  final String? error;

  factory ExternalRecordingStatus.idle() => const ExternalRecordingStatus(
        active: false,
        monitorRunning: false,
        mappingReady: false,
      );
}

