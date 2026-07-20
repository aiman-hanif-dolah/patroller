import 'package:flutter/material.dart';

import '../core/theme/patrol_colors.dart';

/// Icon button with explicit macOS accessibility labels.
class AccessibleIconButton extends StatelessWidget {
  const AccessibleIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.tooltip,
    this.size = 14,
    this.color,
    this.padding,
    this.constraints,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: size, color: color ?? p.textMuted),
        tooltip: tooltip ?? label,
        padding: padding,
        constraints: constraints,
        hoverColor: p.surfaceMuted,
        highlightColor: p.fill,
        splashColor: p.fill,
      ),
    );
  }
}
