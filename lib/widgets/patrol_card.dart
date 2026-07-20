import 'package:flutter/material.dart';

import '../core/theme/patrol_colors.dart';

class PatrolCard extends StatelessWidget {
  const PatrolCard({
    super.key,
    required this.child,
    this.padding,
    this.clipBehavior = Clip.hardEdge,
    this.accentStrip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Clip clipBehavior;
  final bool accentStrip;

  @override
  Widget build(BuildContext context) {
    final p = PatrolPalette.of(context);
    final radius = BorderRadius.circular(PatrolRadius.panel);
    // Shadow/border chrome may live outside Material. Fill must be on Material
    // (or not on an intermediate DecoratedBox): ListTile paints ink on the
    // nearest Material, and a colored DecoratedBox between them asserts.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: p.panelShadows,
      ),
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: p.border),
        ),
        clipBehavior: clipBehavior,
        child: Stack(
          children: [
            if (accentStrip)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  decoration: const BoxDecoration(
                    gradient: PatrolGradients.accentStrip,
                  ),
                ),
              ),
            if (padding != null)
              Padding(padding: padding!, child: child)
            else
              child,
          ],
        ),
      ),
    );
  }
}
