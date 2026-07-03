import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../domain/preview_coordinates.dart';
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
  final _touchFeedback = <_TouchRipple>[];
  Timer? _touchCleanup;

  @override
  void dispose() {
    _touchCleanup?.cancel();
    super.dispose();
  }

  void _addTouchFeedback(Offset position, {bool isLong = false}) {
    final ripple = _TouchRipple(
      position: position,
      createdAt: DateTime.now(),
      isLong: isLong,
    );
    setState(() => _touchFeedback.add(ripple));
    _touchCleanup?.cancel();
    _touchCleanup = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _touchFeedback.removeWhere(
          (r) => DateTime.now().difference(r.createdAt).inMilliseconds > 500,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.collapsed) {
      return _CollapsedPreviewBar(onExpand: widget.onToggleCollapse);
    }

    final preview = ref.watch(previewProvider);
    final device = ref.watch(runnerProvider).selectedDevice;
    final deviceInfo = preview.deviceInfo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PreviewHeader(
          deviceName: device?.name,
          readiness: preview.readiness,
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

                return _PreviewCanvas(
                  preview: preview,
                  layout: layout,
                  touchFeedback: _touchFeedback,
                  onTapAt: (offset) => _handleTap(offset, layout),
                  onLongPressAt: (offset) => _handleLongPress(offset, layout),
                  onPanEnd: (start, end) => _handleSwipe(start, end, layout),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleTap(Offset local, PreviewLayout layout) async {
    final device = mapPreviewToDevice(local: local, layout: layout);
    if (device == null) return;
    _addTouchFeedback(local);
    await ref.read(previewProvider.notifier).tap(device.dx, device.dy);
  }

  Future<void> _handleLongPress(Offset local, PreviewLayout layout) async {
    final device = mapPreviewToDevice(local: local, layout: layout);
    if (device == null) return;
    _addTouchFeedback(local, isLong: true);
    await ref
        .read(previewProvider.notifier)
        .tap(device.dx, device.dy, durationSec: 1.0);
  }

  Future<void> _handleSwipe(
    Offset start,
    Offset end,
    PreviewLayout layout,
  ) async {
    final from = mapPreviewToDevice(local: start, layout: layout);
    final to = mapPreviewToDevice(local: end, layout: layout);
    if (from == null || to == null) return;
    _addTouchFeedback(start);
    await ref.read(previewProvider.notifier).swipe(
          fromX: from.dx,
          fromY: from.dy,
          toX: to.dx,
          toY: to.dy,
        );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({
    required this.deviceName,
    required this.readiness,
    required this.onCollapse,
  });

  final String? deviceName;
  final PreviewReadiness readiness;
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
    required this.preview,
    required this.layout,
    required this.touchFeedback,
    required this.onTapAt,
    required this.onLongPressAt,
    required this.onPanEnd,
  });

  final PreviewState preview;
  final PreviewLayout layout;
  final List<_TouchRipple> touchFeedback;
  final ValueChanged<Offset> onTapAt;
  final ValueChanged<Offset> onLongPressAt;
  final void Function(Offset start, Offset end) onPanEnd;

  @override
  Widget build(BuildContext context) {
    final frame = preview.frame;
    final overlay = preview.highlightFrame;

    if (preview.readiness == PreviewReadiness.noDevice) {
      return const _PreviewMessage('Select a booted iOS Simulator.');
    }
    if (preview.readiness == PreviewReadiness.driverStarting) {
      return const _PreviewMessage('Starting simulator driver…');
    }
    if (preview.readiness == PreviewReadiness.driverUnavailable) {
      return const _PreviewMessage(
        'Simulator driver is not ready. Boot the simulator or check Health.',
      );
    }
    if (preview.error != null && frame == null) {
      return _PreviewMessage(preview.error!);
    }
    if (frame == null &&
        (preview.readiness == PreviewReadiness.loading ||
            preview.readiness == PreviewReadiness.ready)) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    Offset? panStart;

    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => onTapAt(details.localPosition),
        onLongPressStart: (details) => onLongPressAt(details.localPosition),
        onPanStart: (details) => panStart = details.localPosition,
        onPanEnd: (details) {
          final start = panStart;
          if (start == null) return;
          final end = details.localPosition;
          final distance = (end - start).distance;
          if (distance >= 12) {
            onPanEnd(start, end);
          } else {
            onTapAt(end);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (frame != null)
              Center(
                child: Image.memory(
                  frame.bytes,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            if (overlay != null)
              Positioned.fromRect(
                rect: mapDeviceFrameToPreview(frame: overlay, layout: layout) ??
                    Rect.zero,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: PatrolColors.ember, width: 2),
                      color: PatrolColors.ember.withValues(alpha: 0.15),
                    ),
                  ),
                ),
              ),
            for (final ripple in touchFeedback)
              Positioned(
                left: ripple.position.dx - 16,
                top: ripple.position.dy - 16,
                child: IgnorePointer(
                  child: _TouchRippleWidget(ripple: ripple),
                ),
              ),
            if (preview.readiness == PreviewReadiness.stale)
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

class _TouchRipple {
  const _TouchRipple({
    required this.position,
    required this.createdAt,
    this.isLong = false,
  });

  final Offset position;
  final DateTime createdAt;
  final bool isLong;
}

class _TouchRippleWidget extends StatelessWidget {
  const _TouchRippleWidget({required this.ripple});

  final _TouchRipple ripple;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ripple.isLong ? 40 : 32,
      height: ripple.isLong ? 40 : 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: PatrolColors.sky400.withValues(alpha: 0.8),
          width: 2,
        ),
        color: PatrolColors.sky400.withValues(alpha: 0.2),
      ),
    );
  }
}