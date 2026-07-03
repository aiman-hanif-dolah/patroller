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
        borderRadius: BorderRadius.circular(8),
        border: style.border,
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
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
        );
      case 'failed':
      case 'error':
      case 'interrupted':
        return const _BadgeStyle(
          background: Color(0x667F1D1D),
          foreground: PatrolColors.red400,
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
  });

  final Color background;
  final Color foreground;
  final Border? border;
}

class WorkflowStatusBadge extends StatelessWidget {
  const WorkflowStatusBadge({
    super.key,
    required this.label,
    required this.value,
    this.warn = false,
  });

  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: warn
            ? PatrolColors.ember.withValues(alpha: 0.15)
            : PatrolColors.fog,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: warn
              ? PatrolColors.ember.withValues(alpha: 0.3)
              : PatrolColors.pebble.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: warn ? PatrolColors.ember : PatrolColors.steel,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: warn ? FontWeight.w600 : FontWeight.w400,
              color: warn ? PatrolColors.ember : PatrolColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}