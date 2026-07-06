import 'package:flutter/material.dart';

import '../core/theme/patrol_colors.dart';
import 'collapsible_panel.dart';

const double logsPanelDefaultWidth = 640;
const double logsPanelMinWidth = 280;
const double logsPanelMaxWidth = 720;

const double rightPanelDefaultWidth = 380;
const double rightPanelMinWidth = 280;
const double rightPanelMaxWidth = 560;

const double _panelGutter = 12;
const double _shellPadding = 12;

double clampRightPanelWidth(double width) =>
    width.clamp(rightPanelMinWidth, rightPanelMaxWidth);

double availableHorizontalSpace({
  required double totalWidth,
  required double logsWidth,
  required double rightWidth,
  required bool logsCollapsed,
  required bool rightCollapsed,
}) {
  final logs = logsCollapsed ? panelCollapseRailWidth : logsWidth;
  final right = rightCollapsed ? panelCollapseRailWidth : rightWidth;
  final gutters = _panelGutter + (_shellPadding * 2);
  return totalWidth - logs - right - gutters;
}

double clampLogsPanelWidth(
  double width, {
  required double totalWidth,
  required double rightWidth,
  required bool logsCollapsed,
  required bool rightCollapsed,
}) {
  if (logsCollapsed) return panelCollapseRailWidth;

  final right = rightCollapsed ? panelCollapseRailWidth : rightWidth;
  final gutters = _panelGutter + (_shellPadding * 2);
  final maxLogs =
      (totalWidth - right - gutters).clamp(logsPanelMinWidth, logsPanelMaxWidth);
  return width.clamp(logsPanelMinWidth, maxLogs);
}

double minLogsPanelWidth({
  required double totalWidth,
  required double rightWidth,
  required bool logsCollapsed,
  required bool rightCollapsed,
}) {
  return clampLogsPanelWidth(
    logsPanelMinWidth,
    totalWidth: totalWidth,
    rightWidth: rightWidth,
    logsCollapsed: logsCollapsed,
    rightCollapsed: rightCollapsed,
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
          onHorizontalDragEnd: (details) =>
              onDragEnd(details.primaryVelocity ?? 0),
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