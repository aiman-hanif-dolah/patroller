import 'package:flutter/material.dart';

import '../core/theme/patrol_colors.dart';

class PatrolCard extends StatelessWidget {
  const PatrolCard({
    super.key,
    required this.child,
    this.padding,
    this.clipBehavior = Clip.hardEdge,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PatrolColors.mist,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08FFFFFF),
            offset: Offset(0, 1),
            blurRadius: 0,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: clipBehavior,
        child: padding != null ? Padding(padding: padding!, child: child) : child,
      ),
    );
  }
}