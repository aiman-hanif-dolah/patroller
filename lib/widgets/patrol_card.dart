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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PatrolColors.mist,
        borderRadius: BorderRadius.circular(PatrolRadius.panel),
        border: Border.all(
          color: PatrolColors.pebble.withValues(alpha: 0.7),
        ),
        boxShadow: PatrolShadows.panel,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PatrolRadius.panel),
        clipBehavior: clipBehavior,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: PatrolGradients.panelSheen,
                ),
              ),
            ),
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