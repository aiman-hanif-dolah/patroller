import 'enums.dart';

class DeviceInfo {
  const DeviceInfo({
    required this.name,
    required this.id,
    required this.platform,
    required this.type,
    required this.availability,
    required this.rawLine,
    this.state,
  });

  final String name;
  final String id;
  final String platform;
  final DeviceType type;
  final String availability;
  final String rawLine;
  final DeviceState? state;

  Map<String, dynamic> toJson() => {
        'name': name,
        'id': id,
        'platform': platform,
        'type': type.toJson(),
        'availability': availability,
        'rawLine': rawLine,
        if (state != null) 'state': state!.toJson(),
      };

  factory DeviceInfo.fromJson(Map<String, dynamic> json) => DeviceInfo(
        name: json['name'] as String? ?? 'Unknown',
        id: json['id'] as String? ?? '',
        platform: json['platform'] as String? ?? 'unknown',
        type: DeviceType.fromJson(json['type'] as String? ?? 'unknown'),
        availability: json['availability'] as String? ?? 'unknown',
        rawLine: json['rawLine'] as String? ?? '',
        state: json['state'] != null
            ? DeviceState.fromJson(json['state'] as String)
            : null,
      );

  DeviceInfo copyWith({
    String? name,
    String? id,
    String? platform,
    DeviceType? type,
    String? availability,
    String? rawLine,
    DeviceState? state,
  }) =>
      DeviceInfo(
        name: name ?? this.name,
        id: id ?? this.id,
        platform: platform ?? this.platform,
        type: type ?? this.type,
        availability: availability ?? this.availability,
        rawLine: rawLine ?? this.rawLine,
        state: state ?? this.state,
      );
}