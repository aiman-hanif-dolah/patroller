import 'package:flutter/material.dart';

import '../core/theme/patrol_colors.dart';

const double logsPanelDefaultWidth = 640;
const double logsPanelMinWidth = 360;
const double rightPanelDefaultWidth = 380;
const double rightPanelMinWidth = 280;
const double rightPanelMaxWidth = 560;

double clampLogsPanelWidth(double width) =>
    width.clamp(logsPanelMinWidth, 1200);

double clampRightPanelWidth(double width) =>
    width.clamp(rightPanelMinWidth, rightPanelMaxWidth);

class PanelResizeHandle extends StatelessWidget {
  const PanelResizeHandle({
    super.key,
    required this.onDrag,
    required this.onDragEnd,
    this.edge = PanelResizeEdge.left,
  });

  final ValueChanged<double> onDrag;
  final ValueChanged<double> onDragEnd;
  final PanelResizeEdge edge;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: edge == PanelResizeEdge.left ? 0 : null,
      right: edge == PanelResizeEdge.right ? 0 : null,
      top: 0,
      bottom: 0,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: (details) {
            final delta = edge == PanelResizeEdge.left
                ? -details.delta.dx
                : details.delta.dx;
            onDrag(delta);
          },
          onHorizontalDragEnd: (_) {},
          child: Container(
            width: 12,
            alignment: Alignment.center,
            child: Container(
              width: 1,
              margin: const EdgeInsets.symmetric(vertical: 12),
              color: PatrolColors.pebble.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}

enum PanelResizeEdge { left, right }