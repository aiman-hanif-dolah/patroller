import 'dart:typed_data';

enum PreviewReadiness {
  noDevice,
  driverStarting,
  driverUnavailable,
  loading,
  ready,
  stale,
  error,
}

enum PreviewActivityLevel { idle, active, interaction }

class PreviewFrame {
  const PreviewFrame({
    required this.bytes,
    required this.fingerprint,
    required this.capturedAt,
    this.captureDurationMs,
    this.width = 0,
    this.height = 0,
  });

  final Uint8List bytes;
  final String fingerprint;
  final DateTime capturedAt;
  final int? captureDurationMs;
  final int width;
  final int height;
}