import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'patrol_colors.dart';

abstract final class PatrolTheme {
  /// ClickUp-inspired light theme for Patroller.
  static ThemeData light() => _build(
        brightness: Brightness.light,
        palette: PatrolPalette.light,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      );

  /// Zinc dark companion - polished macOS-style dark app chrome.
  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        palette: PatrolPalette.dark,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      );

  static ThemeData _build({
    required Brightness brightness,
    required PatrolPalette palette,
    required SystemUiOverlayStyle systemOverlayStyle,
  }) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: palette.canvas,
      extensions: [palette],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: palette.cta,
        onPrimary: palette.onCta,
        secondary: palette.surfaceMuted,
        onSecondary: palette.text,
        surface: palette.surface,
        onSurface: palette.text,
        error: PatrolColors.psFailed,
        onError: palette.inverse,
        outline: palette.border,
      ),
      dividerColor: palette.border,
      splashColor: palette.fill.withValues(alpha: isDark ? 0.4 : 0.6),
      highlightColor: palette.surfaceMuted.withValues(alpha: isDark ? 0.2 : 1),
      hoverColor: isDark
          ? palette.surfaceMuted.withValues(alpha: 0.35)
          : const Color(0x0A000000),
    );

    final jakarta = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);
    final inter = GoogleFonts.interTextTheme(base.textTheme);

    final textTheme = jakarta
        .copyWith(
          displayLarge: jakarta.displayLarge?.copyWith(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            height: 1.15,
            letterSpacing: -1.6,
            color: palette.textDisplay,
          ),
          headlineSmall: jakarta.headlineSmall?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: palette.text,
          ),
          titleMedium: jakarta.titleMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: palette.text,
          ),
          bodyLarge: inter.bodyLarge?.copyWith(
            fontSize: 16,
            height: 1.5,
            letterSpacing: -0.01,
            color: palette.text,
          ),
          bodyMedium: inter.bodyMedium?.copyWith(
            fontSize: 14,
            height: 1.5,
            letterSpacing: -0.01,
            color: palette.text,
          ),
          bodySmall: inter.bodySmall?.copyWith(
            fontSize: 12,
            height: 1.4,
            color: palette.textMuted,
          ),
          labelSmall: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
            color: palette.textMuted,
          ),
        )
        .apply(
          bodyColor: palette.text,
          displayColor: palette.textDisplay,
        );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        foregroundColor: palette.text,
        elevation: 0,
        systemOverlayStyle: systemOverlayStyle,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PatrolRadius.card),
          side: BorderSide(color: palette.border),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.cta,
          foregroundColor: palette.onCta,
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PatrolRadius.pill),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.text,
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PatrolRadius.pill),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? palette.fill : palette.surface,
        hintStyle: TextStyle(color: palette.textFaint, fontSize: 12),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PatrolRadius.input),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PatrolRadius.input),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PatrolRadius.input),
          borderSide: BorderSide(
            color: isDark ? palette.textSecondary : PatrolColors.signalBlue,
            width: 1.5,
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.cta;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(palette.onCta),
        side: BorderSide(color: palette.borderStrong, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: palette.surfaceMuted,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PatrolRadius.input),
            borderSide: BorderSide(color: palette.border),
          ),
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(palette.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      iconTheme: IconThemeData(color: palette.textMuted, size: 14),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(palette.borderStrong),
        radius: const Radius.circular(9999),
        thickness: WidgetStateProperty.all(5),
        crossAxisMargin: 0,
        mainAxisMargin: 0,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? palette.canvas : palette.cta,
          borderRadius: BorderRadius.circular(8),
          border: isDark ? Border.all(color: palette.border) : null,
        ),
        textStyle: TextStyle(color: isDark ? palette.text : palette.onCta, fontSize: 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PatrolRadius.largeCard),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surface,
        contentTextStyle: TextStyle(color: palette.text),
        behavior: SnackBarBehavior.floating,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PatrolRadius.card),
          side: BorderSide(color: palette.border),
        ),
        textStyle: TextStyle(color: palette.text, fontSize: 13),
      ),
      dividerTheme: DividerThemeData(color: palette.border, space: 1, thickness: 1),
    );
  }
}
