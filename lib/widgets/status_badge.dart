import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/patrol_colors.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final style = _styleFor(status, p);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(PatrolRadius.badge),
        border: Border.all(color: style.foreground.withValues(alpha: 0.22)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: style.foreground,
        ),
      ),
    );
  }

  _BadgeStyle _styleFor(String value, PatrolPalette p) {
    switch (value) {
      case 'passed':
        return const _BadgeStyle(
          background: Color(0x1A22C55E),
          foreground: PatrolColors.green400,
        );
      case 'failed':
      case 'error':
      case 'interrupted':
        return const _BadgeStyle(
          background: Color(0x1AEF4444),
          foreground: PatrolColors.red400,
        );
      case 'cancelled':
      case 'stopped':
      case 'skipped':
        return const _BadgeStyle(
          background: Color(0x1AFB923C),
          foreground: PatrolColors.orange400,
        );
      case 'starting':
      case 'running':
      case 'stopping':
        return _BadgeStyle(
          background: p.psRunning,
          foreground: p.onCta,
        );
      default:
        return _BadgeStyle(
          background: p.fill,
          foreground: p.textMuted,
        );
    }
  }
}

class _BadgeStyle {
  const _BadgeStyle({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
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
    final p = PatrolPalette.of(context);
    final accentColor = accent ?? PatrolColors.signalBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: warn
            ? PatrolColors.ember.withValues(alpha: 0.1)
            : accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(PatrolRadius.pill),
        border: Border.all(
          color: warn
              ? PatrolColors.ember.withValues(alpha: 0.3)
              : accentColor.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: warn ? PatrolColors.ember : accentColor,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: warn ? PatrolColors.ember : p.textMuted,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: warn ? FontWeight.w700 : FontWeight.w500,
              color: warn ? PatrolColors.ember : p.text,
            ),
          ),
        ],
      ),
    );
  }
}
