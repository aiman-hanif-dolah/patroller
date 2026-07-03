import 'dart:typed_data';
import 'dart:ui';

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

enum PreviewGestureKind { tap, longPress, swipe, scroll }

class PreviewMetrics {
  const PreviewMetrics({
    this.emittedFrames = 0,
    this.unchangedFrames = 0,
    this.droppedFrames = 0,
    this.lastCaptureDurationMs,
    this.lastSuccessfulFrameAt,
  });

  final int emittedFrames;
  final int unchangedFrames;
  final int droppedFrames;
  final int? lastCaptureDurationMs;
  final DateTime? lastSuccessfulFrameAt;

  PreviewMetrics copyWith({
    int? emittedFrames,
    int? unchangedFrames,
    int? droppedFrames,
    int? lastCaptureDurationMs,
    DateTime? lastSuccessfulFrameAt,
  }) {
    return PreviewMetrics(
      emittedFrames: emittedFrames ?? this.emittedFrames,
      unchangedFrames: unchangedFrames ?? this.unchangedFrames,
      droppedFrames: droppedFrames ?? this.droppedFrames,
      lastCaptureDurationMs:
          lastCaptureDurationMs ?? this.lastCaptureDurationMs,
      lastSuccessfulFrameAt:
          lastSuccessfulFrameAt ?? this.lastSuccessfulFrameAt,
    );
  }
}

class PreviewInteractionFeedback {
  const PreviewInteractionFeedback({
    required this.kind,
    required this.at,
    this.position,
    this.endPosition,
  });

  final PreviewGestureKind kind;
  final DateTime at;
  final Offset? position;
  final Offset? endPosition;
}

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