import 'package:flutter/material.dart';

import '../core/theme/patrol_colors.dart';

const double logsPanelDefaultWidth = 480;
const double logsPanelMinWidth = 280;
const double logsPanelMaxWidth = 720;

const double previewPanelDefaultWidth = 390;
const double previewPanelMinWidth = 280;
const double previewPanelMaxWidth = 520;

const double rightPanelDefaultWidth = 380;
const double rightPanelMinWidth = 280;
const double rightPanelMaxWidth = 560;

const double _panelGutter = 12;
const double _shellPadding = 12;

double clampPreviewPanelWidth(double width) =>
    width.clamp(previewPanelMinWidth, previewPanelMaxWidth);

double clampRightPanelWidth(double width) =>
    width.clamp(rightPanelMinWidth, rightPanelMaxWidth);

double clampLogsPanelWidth(
  double width, {
  required double totalWidth,
  required double previewWidth,
  required double rightWidth,
  required bool previewCollapsed,
}) {
  final preview = previewCollapsed ? 36.0 : previewWidth;
  final reserved = preview +
      rightWidth +
      (_panelGutter * 2) +
      (_shellPadding * 2);
  final maxLogs = (totalWidth - reserved).clamp(logsPanelMinWidth, 2000.0);
  return width.clamp(logsPanelMinWidth, maxLogs);
}

double minLogsPanelWidth({
  required double totalWidth,
  required double previewWidth,
  required double rightWidth,
  required bool previewCollapsed,
}) {
  return clampLogsPanelWidth(
    logsPanelMinWidth,
    totalWidth: totalWidth,
    previewWidth: previewWidth,
    rightWidth: rightWidth,
    previewCollapsed: previewCollapsed,
  );
}

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
          onHorizontalDragEnd: (details) => onDragEnd(details.primaryVelocity ?? 0),
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