import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/preview_coordinates.dart';
import '../../domain/preview_gestures.dart';
import '../../models/models.dart';
import '../../providers/preview_provider.dart';
import '../../providers/runner_provider.dart';

class SimulatorPreviewPanel extends ConsumerStatefulWidget {
  const SimulatorPreviewPanel({
    super.key,
    required this.collapsed,
    required this.onToggleCollapse,
  });

  final bool collapsed;
  final VoidCallback onToggleCollapse;

  @override
  ConsumerState<SimulatorPreviewPanel> createState() =>
      _SimulatorPreviewPanelState();
}

class _SimulatorPreviewPanelState extends ConsumerState<SimulatorPreviewPanel> {
  Offset? _panStart;
  DateTime? _panStartedAt;
  PreviewLayout? _layout;
  bool _longPressHandled = false;

  @override
  Widget build(BuildContext context) {
    if (widget.collapsed) {
      return _CollapsedPreviewBar(onExpand: widget.onToggleCollapse);
    }

    final preview = ref.watch(previewProvider);
    final device = ref.watch(runnerProvider).selectedDevice;
    final deviceInfo = preview.deviceInfo;
    final canInteract = preview.canInteract;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PreviewHeader(
          deviceName: device?.name,
          readiness: preview.readiness,
          metrics: preview.metrics,
          onCollapse: widget.onToggleCollapse,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final containerSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                final layout = computePreviewLayout(
                  containerSize: containerSize,
                  deviceWidth: (deviceInfo?.widthPoints ?? 390).toDouble(),
                  deviceHeight: (deviceInfo?.heightPoints ?? 844).toDouble(),
                );
                _layout = layout;

                return _PreviewCanvas(
                  frame: preview.frame,
                  readiness: preview.readiness,
                  error: preview.error,
                  highlightFrame: preview.highlightFrame,
                  feedback: preview.interactionFeedback,
                  layout: layout,
                  canInteract: canInteract,
                  onPointerDown: canInteract ? _onPointerDown : null,
                  onPointerUp: canInteract ? _onPointerUp : null,
                  onScroll: canInteract ? _onScroll : null,
                  onLongPress: canInteract ? _onLongPress : null,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _onPointerDown(Offset local) {
    _longPressHandled = false;
    _panStart = local;
    _panStartedAt = DateTime.now();
  }

  Future<void> _onPointerUp(Offset local) async {
    if (_longPressHandled) {
      _longPressHandled = false;
      _panStart = null;
      _panStartedAt = null;
      return;
    }
    final layout = _layout;
    final start = _panStart;
    final startedAt = _panStartedAt;
    _panStart = null;
    _panStartedAt = null;
    if (layout == null || start == null || startedAt == null) return;

    final deviceStart = mapPreviewToDevice(local: start, layout: layout);
    final deviceEnd = mapPreviewToDevice(local: local, layout: layout);
    if (deviceStart == null || deviceEnd == null) return;

    final gesture = classifyPointerGesture(
      start: deviceStart,
      end: deviceEnd,
      elapsed: DateTime.now().difference(startedAt),
    );
    await ref.read(previewProvider.notifier).performGesture(gesture);
  }

  Future<void> _onLongPress(Offset local) async {
    final layout = _layout;
    if (layout == null) return;
    final device = mapPreviewToDevice(local: local, layout: layout);
    if (device == null) return;
    _longPressHandled = true;
    await ref.read(previewProvider.notifier).performGesture(
          ClassifiedGesture(
            kind: PreviewGestureKind.longPress,
            start: device,
            durationSec: 1.0,
          ),
        );
  }

  Future<void> _onScroll(Offset local, double scrollDeltaY) async {
    final layout = _layout;
    if (layout == null || scrollDeltaY.abs() < scrollMinDelta) return;
    final devicePoint = mapPreviewToDevice(local: local, layout: layout);
    if (devicePoint == null) return;

    final scroll = scrollGestureFromWheel(
      devicePoint: devicePoint,
      scrollDeltaY: scrollDeltaY,
      layout: layout,
    );
    await ref.read(previewProvider.notifier).performGesture(
          ClassifiedGesture(
            kind: PreviewGestureKind.scroll,
            start: scroll.start,
            end: scroll.end,
            durationSec: scroll.durationSec,
          ),
        );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Image.memory(
        bytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({
    required this.deviceName,
    required this.readiness,
    required this.metrics,
    required this.onCollapse,
  });

  final String? deviceName;
  final PreviewReadiness readiness;
  final PreviewMetrics metrics;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PatrolColors.pebble)),
      ),
      child: Row(
        children: [
          const Icon(Icons.smartphone, size: 12, color: PatrolColors.steel),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              deviceName ?? 'Simulator',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: PatrolColors.ink,
              ),
            ),
          ),
          if (metrics.lastCaptureDurationMs != null)
            Text(
              '${metrics.lastCaptureDurationMs}ms',
              style: const TextStyle(fontSize: 9, color: PatrolColors.steel),
            ),
          const SizedBox(width: 6),
          _ReadinessDot(readiness: readiness),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onCollapse,
            icon: const Icon(Icons.chevron_left, size: 16),
            tooltip: 'Collapse preview',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _ReadinessDot extends StatelessWidget {
  const _ReadinessDot({required this.readiness});

  final PreviewReadiness readiness;

  @override
  Widget build(BuildContext context) {
    final color = switch (readiness) {
      PreviewReadiness.ready => PatrolColors.psPassed,
      PreviewReadiness.loading || PreviewReadiness.driverStarting =>
        PatrolColors.sky400,
      PreviewReadiness.stale => PatrolColors.ember,
      PreviewReadiness.error || PreviewReadiness.driverUnavailable =>
        PatrolColors.red400,
      PreviewReadiness.noDevice => PatrolColors.steel,
    };
    return Tooltip(
      message: _readinessLabel(readiness),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  String _readinessLabel(PreviewReadiness readiness) {
    return switch (readiness) {
      PreviewReadiness.noDevice => 'No device selected',
      PreviewReadiness.driverStarting => 'Driver starting',
      PreviewReadiness.driverUnavailable => 'Driver unavailable',
      PreviewReadiness.loading => 'Loading frame',
      PreviewReadiness.ready => 'Live preview',
      PreviewReadiness.stale => 'Stale frame',
      PreviewReadiness.error => 'Screenshot error',
    };
  }
}

class _CollapsedPreviewBar extends StatelessWidget {
  const _CollapsedPreviewBar({required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onExpand,
      child: Container(
        width: 36,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: PatrolColors.pebble)),
        ),
        child: RotatedBox(
          quarterTurns: 3,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.smartphone, size: 12, color: PatrolColors.steel),
              const SizedBox(width: 6),
              const Text(
                'PREVIEW',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: PatrolColors.steel,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 14, color: PatrolColors.steel),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewCanvas extends StatelessWidget {
  const _PreviewCanvas({
    required this.frame,
    required this.readiness,
    required this.error,
    required this.highlightFrame,
    required this.feedback,
    required this.layout,
    required this.canInteract,
    this.onPointerDown,
    this.onPointerUp,
    this.onScroll,
    this.onLongPress,
  });

  final PreviewFrame? frame;
  final PreviewReadiness readiness;
  final String? error;
  final ElementFrame? highlightFrame;
  final PreviewInteractionFeedback? feedback;
  final PreviewLayout layout;
  final bool canInteract;
  final void Function(Offset local)? onPointerDown;
  final Future<void> Function(Offset local)? onPointerUp;
  final Future<void> Function(Offset local, double scrollDeltaY)? onScroll;
  final Future<void> Function(Offset local)? onLongPress;

  @override
  Widget build(BuildContext context) {
    if (readiness == PreviewReadiness.noDevice) {
      return const _PreviewMessage('Select a booted iOS Simulator.');
    }
    if (readiness == PreviewReadiness.driverStarting) {
      return const _PreviewMessage('Starting simulator driver…');
    }
    if (readiness == PreviewReadiness.driverUnavailable) {
      return const _PreviewMessage(
        'Simulator driver is not ready. Boot the simulator or check Health.',
      );
    }
    if (error != null && frame == null) {
      return _PreviewMessage(error!);
    }
    if (frame == null &&
        (readiness == PreviewReadiness.loading ||
            readiness == PreviewReadiness.ready)) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final highlightRect = highlightFrame != null
        ? mapDeviceFrameToPreview(frame: highlightFrame!, layout: layout)
        : null;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: onPointerDown == null
          ? null
          : (event) => onPointerDown!(event.localPosition),
      onPointerUp: onPointerUp == null
          ? null
          : (event) => unawaited(onPointerUp!(event.localPosition)),
      onPointerSignal: onScroll == null
          ? null
          : (event) {
              if (event is PointerScrollEvent) {
                unawaited(onScroll!(event.localPosition, event.scrollDelta.dy));
              }
            },
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onLongPressStart: onLongPress == null
            ? null
            : (details) => unawaited(onLongPress!(details.localPosition)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (frame != null) Center(child: _PreviewImage(bytes: frame!.bytes)),
            if (!canInteract)
              const Positioned.fill(
                child: ColoredBox(color: Color(0x22000000)),
              ),
            if (highlightRect != null)
              Positioned.fromRect(
                rect: highlightRect,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: PatrolColors.ember, width: 2),
                      color: PatrolColors.ember.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              ),
            if (feedback != null) _InteractionFeedbackOverlay(
              feedback: feedback!,
              layout: layout,
            ),
            if (readiness == PreviewReadiness.stale)
              const Positioned(
                left: 8,
                bottom: 8,
                child: _StaleBadge(),
              ),
          ],
        ),
      ),
    );
  }
}

class _InteractionFeedbackOverlay extends StatelessWidget {
  const _InteractionFeedbackOverlay({
    required this.feedback,
    required this.layout,
  });

  final PreviewInteractionFeedback feedback;
  final PreviewLayout layout;

  @override
  Widget build(BuildContext context) {
    final start = feedback.position;
    if (start == null) return const SizedBox.shrink();

    final previewStart = _deviceToPreview(start, layout);
    if (previewStart == null) return const SizedBox.shrink();

    if (feedback.kind == PreviewGestureKind.swipe ||
        feedback.kind == PreviewGestureKind.scroll) {
      final end = feedback.endPosition;
      if (end == null) return const SizedBox.shrink();
      final previewEnd = _deviceToPreview(end, layout);
      if (previewEnd == null) return const SizedBox.shrink();
      return CustomPaint(
        painter: _SwipeFeedbackPainter(
          start: previewStart,
          end: previewEnd,
          color: feedback.kind == PreviewGestureKind.scroll
              ? PatrolColors.violet500
              : PatrolColors.sky400,
        ),
        child: const SizedBox.expand(),
      );
    }

    final isLong = feedback.kind == PreviewGestureKind.longPress;
    return Positioned(
      left: previewStart.dx - (isLong ? 20 : 16),
      top: previewStart.dy - (isLong ? 20 : 16),
      child: IgnorePointer(
        child: Container(
          width: isLong ? 40 : 32,
          height: isLong ? 40 : 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: (isLong ? PatrolColors.ember : PatrolColors.sky400)
                  .withValues(alpha: 0.85),
              width: 2,
            ),
            color: PatrolColors.sky400.withValues(alpha: 0.18),
          ),
        ),
      ),
    );
  }

  Offset? _deviceToPreview(Offset device, PreviewLayout layout) {
    return mapDeviceToPreview(device: device, layout: layout);
  }
}

class _SwipeFeedbackPainter extends CustomPainter {
  _SwipeFeedbackPainter({
    required this.start,
    required this.end,
    required this.color,
  });

  final Offset start;
  final Offset end;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, paint);
    canvas.drawCircle(start, 5, paint..style = PaintingStyle.fill);
    canvas.drawCircle(end, 4, paint);
  }

  @override
  bool shouldRepaint(covariant _SwipeFeedbackPainter oldDelegate) =>
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.color != color;
}

class _PreviewMessage extends StatelessWidget {
  const _PreviewMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: PatrolColors.steel),
        ),
      ),
    );
  }
}

class _StaleBadge extends StatelessWidget {
  const _StaleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PatrolColors.obsidian.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PatrolColors.ember.withValues(alpha: 0.5)),
      ),
      child: const Text(
        'Stale',
        style: TextStyle(fontSize: 9, color: PatrolColors.ember),
      ),
    );
  }
}