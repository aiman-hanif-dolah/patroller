import 'enums.dart';

class HealthCheck {
  const HealthCheck({
    required this.name,
    required this.status,
    required this.explanation,
    required this.fixInstruction,
    required this.rawOutput,
  });

  final String name;
  final HealthStatus status;
  final String explanation;
  final String fixInstruction;
  final String rawOutput;

  Map<String, dynamic> toJson() => {
        'name': name,
        'status': status.toJson(),
        'explanation': explanation,
        'fixInstruction': fixInstruction,
        'rawOutput': rawOutput,
      };

  factory HealthCheck.fromJson(Map<String, dynamic> json) => HealthCheck(
        name: json['name'] as String? ?? '',
        status: HealthStatus.fromJson(json['status'] as String? ?? 'failed'),
        explanation: json['explanation'] as String? ?? '',
        fixInstruction: json['fixInstruction'] as String? ?? '',
        rawOutput: json['rawOutput'] as String? ?? '',
      );
}