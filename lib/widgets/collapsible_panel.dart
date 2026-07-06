import 'package:flutter/material.dart';

import '../core/theme/patrol_colors.dart';
import 'accessible_icon_button.dart';
import 'patrol_components.dart';

const double panelCollapseRailWidth = 36;

class CollapsiblePanelRail extends StatelessWidget {
  const CollapsiblePanelRail({
    super.key,
    required this.label,
    required this.icon,
    required this.onExpand,
    this.active = false,
    this.edge = PanelEdge.left,
  });

  final String label;
  final IconData icon;
  final VoidCallback onExpand;
  final bool active;
  final PanelEdge edge;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(PatrolRadius.panel),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onExpand,
          child: Container(
            width: panelCollapseRailWidth,
            decoration: BoxDecoration(
              color: PatrolColors.mist,
              border: Border.all(color: PatrolColors.pebble.withValues(alpha: 0.7)),
              gradient: active
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        PatrolColors.amber.withValues(alpha: 0.12),
                        PatrolColors.mist,
                      ],
                    )
                  : null,
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Icon(
                  icon,
                  size: 14,
                  color: active ? PatrolColors.amberBright : PatrolColors.steel,
                ),
                const SizedBox(height: 8),
                RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: active ? PatrolColors.amberBright : PatrolColors.steel,
                    ),
                  ),
                ),
                const Spacer(),
                AccessibleIconButton(
                  icon: edge == PanelEdge.right
                      ? Icons.chevron_left
                      : Icons.chevron_right,
                  label: 'Expand $label panel',
                  onPressed: onExpand,
                  size: 14,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum PanelEdge { left, right }

class CollapsiblePanelHeader extends StatelessWidget {
  const CollapsiblePanelHeader({
    super.key,
    required this.title,
    required this.onCollapse,
    this.trailing,
    this.edge = PanelEdge.left,
  });

  final String title;
  final VoidCallback onCollapse;
  final Widget? trailing;
  final PanelEdge edge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: PatrolColors.obsidian.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: PatrolColors.pebble.withValues(alpha: 0.7)),
        ),
      ),
      child: Row(
        children: [
          PatrolAvatar(
            icon: title.toLowerCase() == 'logs'
                ? Icons.terminal_rounded
                : Icons.dashboard_outlined,
            size: 24,
          ),
          const SizedBox(width: 8),
          PatrolEyebrow(title),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            Expanded(child: trailing!),
          ] else
            const Spacer(),
          AccessibleIconButton(
            icon: edge == PanelEdge.right
                ? Icons.chevron_right
                : Icons.chevron_left,
            label: 'Collapse $title panel',
            onPressed: onCollapse,
            size: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}