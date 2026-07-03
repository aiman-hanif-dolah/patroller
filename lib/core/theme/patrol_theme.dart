import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'patrol_colors.dart';

abstract final class PatrolTheme {
  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: PatrolColors.obsidian,
      colorScheme: const ColorScheme.dark(
        surface: PatrolColors.obsidian,
        onSurface: PatrolColors.ink,
        primary: PatrolColors.ink,
        onPrimary: PatrolColors.obsidian,
        secondary: PatrolColors.fog,
        onSecondary: PatrolColors.ink,
        outline: PatrolColors.pebble,
        error: PatrolColors.psFailed,
      ),
      dividerColor: PatrolColors.pebble,
      splashColor: PatrolColors.fog.withValues(alpha: 0.4),
      highlightColor: PatrolColors.fog.withValues(alpha: 0.2),
      hoverColor: PatrolColors.fog.withValues(alpha: 0.35),
    );

    final textTheme = GoogleFonts.dmSansTextTheme(base.textTheme).apply(
      bodyColor: PatrolColors.ink,
      displayColor: PatrolColors.ink,
    );

    return base.copyWith(
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          height: 1.56,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          fontSize: 10,
          height: 1.8,
          color: PatrolColors.steel,
        ),
        labelSmall: textTheme.labelSmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: PatrolColors.steel,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: PatrolColors.mist,
        foregroundColor: PatrolColors.ink,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: PatrolColors.mist,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PatrolColors.fog,
        hintStyle: const TextStyle(color: PatrolColors.steel, fontSize: 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10000),
          borderSide: const BorderSide(color: PatrolColors.pebble),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10000),
          borderSide: const BorderSide(color: PatrolColors.pebble),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10000),
          borderSide: const BorderSide(color: PatrolColors.graphite, width: 1.5),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return PatrolColors.ink;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(PatrolColors.obsidian),
        side: const BorderSide(color: PatrolColors.pebble, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      iconTheme: const IconThemeData(color: PatrolColors.steel, size: 14),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(PatrolColors.pebble),
        radius: const Radius.circular(10000),
        thickness: WidgetStateProperty.all(5),
        crossAxisMargin: 0,
        mainAxisMargin: 0,
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: PatrolColors.obsidian,
          border: Border.fromBorderSide(BorderSide(color: PatrolColors.pebble)),
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        textStyle: TextStyle(color: PatrolColors.ink, fontSize: 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: PatrolColors.mist,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: PatrolColors.mist,
        contentTextStyle: TextStyle(color: PatrolColors.ink),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}