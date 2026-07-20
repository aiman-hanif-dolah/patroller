import 'package:flutter/material.dart';

/// Patroller design tokens — ClickUp light system + zinc dark companion.
///
/// Structural / surface colors for light live here as constants.
/// Prefer [PatrolPalette.of] in widgets so light and dark stay in sync.
/// Semantic accents (buttons, statuses, logs, tabs) are shared across themes.
abstract final class PatrolColors {
  // ── ClickUp surfaces (light) ──────────────────────────────────────
  static const signalWhite = Color(0xFFFFFFFF);
  static const mist = Color(0xFFF8F9FA); // card / elevated surface
  static const plaster = Color(0xFFE9EBF0); // section band / shell bg
  static const mercury = Color(0xFFEEEEEE); // chip / input fill

  // ── ClickUp text (light) ──────────────────────────────────────────
  static const ink = Color(0xFF202020); // primary text / ink black
  static const onyx = Color(0xFF090C1D); // display headlines
  static const carbon = Color(0xFF2A2A2A); // structural dark
  static const graphite = Color(0xFF646464); // secondary body (ClickUp slate)
  static const slate = Color(0xFF646464);
  static const steel = Color(0xFF838383); // tertiary / muted (ClickUp ash)
  static const ash = Color(0xFFB3B3B3); // placeholders (ClickUp fog)

  // ── ClickUp borders / fills (light) ───────────────────────────────
  static const bone = Color(0xFFE8E8E8); // default border
  static const cloud = Color(0xFFD4D4D4); // hairline
  static const pebble = Color(0xFFE8E8E8); // alias → bone
  static const fog = Color(0xFFEEEEEE); // alias → mercury (input fills)

  // ── Contrast aliases used across widgets ──────────────────────────
  /// Near-black for text-on-accent and filled CTAs (ClickUp ink black).
  static const obsidian = Color(0xFF202020);
  static const snow = Color(0xFFFFFFFF);

  // ── ClickUp brand accents (non-semantic chrome) ───────────────────
  static const brandViolet = Color(0xFF6647F0);
  static const signalBlue = Color(0xFF0091FF);
  static const mint = Color(0xFF6EE7B7);
  static const emerald = Color(0xFF00C07A);
  static const tealTag = Color(0xFF16C0A4);

  // ── Preserved semantic: brand compass ─────────────────────────────
  static const amber = Color(0xFFF5B800);
  static const amberBright = Color(0xFFFFD54F);
  static const amberMuted = Color(0xFF92700A);
  static const ember = Color(0xFFFF5A00);

  // ── Preserved semantic: pass / fail / run lifecycle ───────────────
  static const psPassed = Color(0xFF22C55E);
  static const psFailed = Color(0xFFEF4444);
  static const psCancelled = Color(0xFFFF5A00);
  static const psRunning = Color(0xFF202020);

  // ── Preserved semantic: action / tab / log accents ────────────────
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

/// Zinc dark companion tokens used to build [PatrolPalette.dark].
abstract final class PatrolDarkColors {
  static const canvas = Color(0xFF09090B); // obsidian
  static const surface = Color(0xFF18181B); // elevated panels
  static const surfaceMuted = Color(0xFF27272A); // fog
  static const fill = Color(0xFF27272A);
  static const text = Color(0xFFFAFAFA);
  static const textDisplay = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFA1A1AA); // graphite
  static const textMuted = Color(0xFF71717A); // steel
  static const textFaint = Color(0xFF52525B); // ash
  static const border = Color(0xFF3F3F46); // pebble
  static const borderStrong = Color(0xFF52525B);
  static const cta = Color(0xFFFAFAFA);
  static const onCta = Color(0xFF09090B);
  static const onAccent = Color(0xFF09090B);
  static const inverse = Color(0xFFFFFFFF);
  static const psRunning = Color(0xFFFAFAFA);
}

/// Theme-aware structural palette. Semantic accents stay on [PatrolColors].
@immutable
class PatrolPalette extends ThemeExtension<PatrolPalette> {
  const PatrolPalette({
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.fill,
    required this.text,
    required this.textDisplay,
    required this.textSecondary,
    required this.textMuted,
    required this.textFaint,
    required this.border,
    required this.borderStrong,
    required this.cta,
    required this.onCta,
    required this.onAccent,
    required this.inverse,
    required this.psRunning,
    required this.panelShadows,
    required this.panelSheen,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceMuted;
  final Color fill;
  final Color text;
  final Color textDisplay;
  final Color textSecondary;
  final Color textMuted;
  final Color textFaint;
  final Color border;
  final Color borderStrong;
  final Color cta;
  final Color onCta;
  final Color onAccent;
  final Color inverse;
  final Color psRunning;
  final List<BoxShadow> panelShadows;
  final Gradient panelSheen;

  static const light = PatrolPalette(
    canvas: PatrolColors.plaster,
    surface: PatrolColors.signalWhite,
    surfaceMuted: PatrolColors.mist,
    fill: PatrolColors.mercury,
    text: PatrolColors.ink,
    textDisplay: PatrolColors.onyx,
    textSecondary: PatrolColors.graphite,
    textMuted: PatrolColors.steel,
    textFaint: PatrolColors.ash,
    border: PatrolColors.bone,
    borderStrong: PatrolColors.cloud,
    cta: PatrolColors.ink,
    onCta: PatrolColors.signalWhite,
    onAccent: PatrolColors.obsidian,
    inverse: PatrolColors.snow,
    psRunning: PatrolColors.psRunning,
    panelShadows: PatrolShadows.panel,
    panelSheen: PatrolGradients.panelSheen,
  );

  static const dark = PatrolPalette(
    canvas: PatrolDarkColors.canvas,
    surface: PatrolDarkColors.surface,
    surfaceMuted: PatrolDarkColors.surfaceMuted,
    fill: PatrolDarkColors.fill,
    text: PatrolDarkColors.text,
    textDisplay: PatrolDarkColors.textDisplay,
    textSecondary: PatrolDarkColors.textSecondary,
    textMuted: PatrolDarkColors.textMuted,
    textFaint: PatrolDarkColors.textFaint,
    border: PatrolDarkColors.border,
    borderStrong: PatrolDarkColors.borderStrong,
    cta: PatrolDarkColors.cta,
    onCta: PatrolDarkColors.onCta,
    onAccent: PatrolDarkColors.onAccent,
    inverse: PatrolDarkColors.inverse,
    psRunning: PatrolDarkColors.psRunning,
    panelShadows: PatrolShadows.panelDark,
    panelSheen: PatrolGradients.panelSheenDark,
  );

  static PatrolPalette of(BuildContext context) {
    final palette = Theme.of(context).extension<PatrolPalette>();
    assert(palette != null, 'PatrolPalette missing from ThemeData.extensions');
    return palette ?? PatrolPalette.light;
  }

  @override
  PatrolPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceMuted,
    Color? fill,
    Color? text,
    Color? textDisplay,
    Color? textSecondary,
    Color? textMuted,
    Color? textFaint,
    Color? border,
    Color? borderStrong,
    Color? cta,
    Color? onCta,
    Color? onAccent,
    Color? inverse,
    Color? psRunning,
    List<BoxShadow>? panelShadows,
    Gradient? panelSheen,
  }) {
    return PatrolPalette(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      fill: fill ?? this.fill,
      text: text ?? this.text,
      textDisplay: textDisplay ?? this.textDisplay,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textFaint: textFaint ?? this.textFaint,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      cta: cta ?? this.cta,
      onCta: onCta ?? this.onCta,
      onAccent: onAccent ?? this.onAccent,
      inverse: inverse ?? this.inverse,
      psRunning: psRunning ?? this.psRunning,
      panelShadows: panelShadows ?? this.panelShadows,
      panelSheen: panelSheen ?? this.panelSheen,
    );
  }

  @override
  PatrolPalette lerp(ThemeExtension<PatrolPalette>? other, double t) {
    if (other is! PatrolPalette) return this;
    return PatrolPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      fill: Color.lerp(fill, other.fill, t)!,
      text: Color.lerp(text, other.text, t)!,
      textDisplay: Color.lerp(textDisplay, other.textDisplay, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      cta: Color.lerp(cta, other.cta, t)!,
      onCta: Color.lerp(onCta, other.onCta, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      inverse: Color.lerp(inverse, other.inverse, t)!,
      psRunning: Color.lerp(psRunning, other.psRunning, t)!,
      panelShadows: t < 0.5 ? panelShadows : other.panelShadows,
      panelSheen: t < 0.5 ? panelSheen : other.panelSheen,
    );
  }
}

abstract final class PatrolGradients {
  static const brandGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [PatrolColors.amberBright, PatrolColors.amber],
  );

  /// Soft top sheen for light cards — nearly invisible flat hierarchy.
  static const panelSheen = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x08FFFFFF), Color(0x00FFFFFF)],
  );

  static const panelSheenDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x10FFFFFF), Color(0x00FFFFFF)],
  );

  static const accentStrip = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [PatrolColors.brandViolet, PatrolColors.signalBlue],
  );

  static const primaryBrand = LinearGradient(
    begin: Alignment(-0.2, 0),
    end: Alignment(1.2, 0),
    colors: [Color(0xFF40DDFF), Color(0xFF7612FA), Color(0xFFFA18E3)],
  );
}

abstract final class PatrolShadows {
  static List<BoxShadow> glow(Color color, {double blur = 14}) => [
        BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: blur),
      ];

  /// ClickUp flat-first: hairline elevation via soft shadow, not heavy drop.
  static const panel = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const panelDark = [
    BoxShadow(
      color: Color(0x50000000),
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];

  static const subtle = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 3,
      offset: Offset(0, 1),
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
  static const s28 = 28.0;
  static const s32 = 32.0;
}

abstract final class PatrolRadius {
  static const badge = 9999.0; // ClickUp status / badge pill
  static const input = 9.0;
  static const chip = 9999.0; // ClickUp pill chips
  static const card = 12.0;
  static const panel = 12.0;
  static const largeCard = 20.0;
  static const pill = 9999.0;
  static const image = 16.0;
}
