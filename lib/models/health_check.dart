import 'enums.dart';

class HealthCheck {
  const HealthCheck({
    required this.name,
    required this.status,
    required this.explanation,
    required this.fixInstruction,
    required this.rawOutput,
    this.copyCommand,
  });

  final String name;
  final HealthStatus status;
  final String explanation;
  final String fixInstruction;
  final String rawOutput;

  /// Optional shell command the user can copy to fix this check.
  final String? copyCommand;

  Map<String, dynamic> toJson() => {
        'name': name,
        'status': status.toJson(),
        'explanation': explanation,
        'fixInstruction': fixInstruction,
        'rawOutput': rawOutput,
        if (copyCommand != null) 'copyCommand': copyCommand,
      };

  factory HealthCheck.fromJson(Map<String, dynamic> json) => HealthCheck(
        name: json['name'] as String? ?? '',
        status: HealthStatus.fromJson(json['status'] as String? ?? 'failed'),
        explanation: json['explanation'] as String? ?? '',
        fixInstruction: json['fixInstruction'] as String? ?? '',
        rawOutput: json['rawOutput'] as String? ?? '',
        copyCommand: json['copyCommand'] as String?,
      );
}