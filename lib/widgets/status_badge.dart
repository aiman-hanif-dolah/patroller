import 'package:flutter/material.dart';

import '../core/theme/patrol_colors.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(PatrolRadius.badge),
        border: style.border ??
            Border.all(color: style.foreground.withValues(alpha: 0.25)),
        boxShadow: style.glow
            ? PatrolShadows.glow(style.foreground, blur: 6)
            : null,
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: style.foreground,
        ),
      ),
    );
  }

  _BadgeStyle _styleFor(String value) {
    switch (value) {
      case 'passed':
        return const _BadgeStyle(
          background: Color(0x66145A32),
          foreground: PatrolColors.green400,
          glow: true,
        );
      case 'failed':
      case 'error':
      case 'interrupted':
        return const _BadgeStyle(
          background: Color(0x667F1D1D),
          foreground: PatrolColors.red400,
          glow: true,
        );
      case 'cancelled':
      case 'stopped':
      case 'skipped':
        return const _BadgeStyle(
          background: Color(0x667C2D12),
          foreground: PatrolColors.orange400,
        );
      case 'starting':
      case 'running':
      case 'stopping':
        return const _BadgeStyle(
          background: PatrolColors.ink,
          foreground: PatrolColors.obsidian,
          glow: true,
        );
      default:
        return const _BadgeStyle(
          background: PatrolColors.pebble,
          foreground: PatrolColors.steel,
        );
    }
  }
}

class _BadgeStyle {
  const _BadgeStyle({
    required this.background,
    required this.foreground,
    this.border,
    this.glow = false,
  });

  final Color background;
  final Color foreground;
  final Border? border;
  final bool glow;
}

class WorkflowStatusBadge extends StatelessWidget {
  const WorkflowStatusBadge({
    super.key,
    required this.label,
    required this.value,
    this.warn = false,
    this.icon,
    this.accent,
  });

  final String label;
  final String value;
  final bool warn;
  final IconData? icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: warn
            ? PatrolColors.ember.withValues(alpha: 0.12)
            : (accent ?? PatrolColors.fog).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(PatrolRadius.chip),
        border: Border.all(
          color: warn
              ? PatrolColors.ember.withValues(alpha: 0.35)
              : (accent ?? PatrolColors.pebble).withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: warn ? PatrolColors.ember : (accent ?? PatrolColors.steel)),
            const SizedBox(width: 6),
          ],
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: warn ? PatrolColors.ember : PatrolColors.steel,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: warn ? FontWeight.w700 : FontWeight.w500,
              color: warn ? PatrolColors.ember : PatrolColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}