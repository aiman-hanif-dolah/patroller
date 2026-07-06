import 'package:flutter/material.dart';

/// Patroller design tokens — dark zinc palette with amber compass accent.
abstract final class PatrolColors {
  static const obsidian = Color(0xFF09090B);
  static const ink = Color(0xFFFAFAFA);
  static const graphite = Color(0xFFA1A1AA);
  static const slate = Color(0xFFD4D4D8);
  static const steel = Color(0xFF71717A);
  static const ash = Color(0xFF52525B);
  static const pebble = Color(0xFF3F3F46);
  static const fog = Color(0xFF27272A);
  static const mist = Color(0xFF18181B);
  static const snow = Color(0xFFFFFFFF);
  static const ember = Color(0xFFFF5A00);

  // Brand compass accent (yellow/black logo)
  static const amber = Color(0xFFF5B800);
  static const amberBright = Color(0xFFFFD54F);
  static const amberMuted = Color(0xFF92700A);

  static const psPassed = Color(0xFF22C55E);
  static const psFailed = Color(0xFFEF4444);
  static const psCancelled = Color(0xFFFF5A00);
  static const psRunning = Color(0xFFFAFAFA);

  static const sky400 = Color(0xFF38BDF8);
  static const violet400 = Color(0xFFA78BFA);
  static const violet500 = Color(0xFF8B5CF6);
  static const fuchsia400 = Color(0xFFE879F9);
  static const fuchsia500 = Color(0xFFD946EF);
  static const red400 = Color(0xFFF87171);
  static const amber300 = Color(0xFFFCD34D);
  static const amber400 = Color(0xFFFBBF24);
  static const rose300 = Color(0xFFFDA4AF);
  static const green400 = Color(0xFF4ADE80);
  static const orange400 = Color(0xFFFB923C);
}

abstract final class PatrolGradients {
  static const brandGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [PatrolColors.amberBright, PatrolColors.amber],
  );

  static const panelSheen = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x10FFFFFF), Color(0x00FFFFFF)],
  );

  static const accentStrip = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [PatrolColors.amberBright, PatrolColors.amberMuted],
  );
}

abstract final class PatrolShadows {
  static List<BoxShadow> glow(Color color, {double blur = 14}) => [
    BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: blur),
  ];

  static const panel = [
    BoxShadow(
      color: Color(0x50000000),
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];
}

abstract final class PatrolSpacing {
  static const s4 = 4.0;
  static const s6 = 6.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
}

abstract final class PatrolRadius {
  static const badge = 6.0;
  static const input = 10.0;
  static const chip = 12.0;
  static const card = 18.0;
  static const panel = 20.0;
  static const pill = 100.0;
}