import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static const _cuerpo = 'DM Sans';
  static const _titulos = 'Space Grotesk';

  static ThemeData get claro => _construir(
        const ColorScheme(
          brightness: Brightness.light,
          primary: AcPalette.primary,
          onPrimary: Colors.white,
          secondary: AcPalette.secondary,
          onSecondary: AcPalette.primary,
          tertiary: AcPalette.accentForeground,
          onTertiary: Colors.white,
          tertiaryContainer: AcPalette.accent,
          onTertiaryContainer: AcPalette.accentForeground,
          error: AcPalette.destructive,
          onError: Colors.white,
          surface: AcPalette.background,
          onSurface: AcPalette.foreground,
          onSurfaceVariant: AcPalette.mutedForeground,
          surfaceContainerLowest: AcPalette.card,
          surfaceContainerLow: AcPalette.card,
          surfaceContainer: AcPalette.muted,
          surfaceContainerHighest: AcPalette.secondary,
          outline: AcPalette.ring,
          outlineVariant: AcPalette.border,
        ),
        AcColors.light,
      );

  static ThemeData get oscuro => _construir(
        const ColorScheme(
          brightness: Brightness.dark,
          primary: AcPalette.darkPrimary,
          onPrimary: AcPalette.darkPrimaryForeground,
          secondary: AcPalette.darkSecondary,
          onSecondary: AcPalette.darkForeground,
          tertiary: AcPalette.darkAccentForeground,
          onTertiary: AcPalette.darkBackground,
          tertiaryContainer: AcPalette.darkAccent,
          onTertiaryContainer: AcPalette.darkAccentForeground,
          error: AcPalette.darkDestructive,
          onError: AcPalette.darkBackground,
          surface: AcPalette.darkBackground,
          onSurface: AcPalette.darkForeground,
          onSurfaceVariant: AcPalette.darkMutedForeground,
          surfaceContainerLowest: AcPalette.darkCard,
          surfaceContainerLow: AcPalette.darkCard,
          surfaceContainer: AcPalette.darkMuted,
          surfaceContainerHighest: AcPalette.darkSecondary,
          outline: AcPalette.darkPrimary,
          outlineVariant: AcPalette.darkBorder,
        ),
        AcColors.dark,
      );

  static ThemeData _construir(ColorScheme cs, AcColors ac) {
    final base = ThemeData(useMaterial3: true, colorScheme: cs, fontFamily: _cuerpo);
    final texto = base.textTheme.apply(bodyColor: cs.onSurface, displayColor: cs.onSurface);

    TextStyle? titulo(TextStyle? s, double size) =>
        s?.copyWith(fontFamily: _titulos, fontSize: size, fontWeight: FontWeight.w600, letterSpacing: -0.6, height: 1.1);

    final radio = BorderRadius.circular(16);

    return base.copyWith(
      scaffoldBackgroundColor: cs.surface,
      extensions: [ac],
      textTheme: texto.copyWith(
        headlineLarge: titulo(texto.headlineLarge, 28),
        headlineMedium: titulo(texto.headlineMedium, 24),
        headlineSmall: titulo(texto.headlineSmall, 20),
        titleLarge: titulo(texto.titleLarge, 19)?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: texto.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
        bodyMedium: texto.bodyMedium?.copyWith(fontSize: 13, height: 1.45),
        bodySmall: texto.bodySmall?.copyWith(fontSize: 11.5, color: cs.onSurfaceVariant, height: 1.4),
        labelLarge: texto.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 14),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: titulo(texto.titleLarge, 19)?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: cs.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: radio),
          textStyle: const TextStyle(fontFamily: _cuerpo, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: cs.primary,
          side: BorderSide(color: cs.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: radio),
          textStyle: const TextStyle(fontFamily: _cuerpo, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          textStyle: const TextStyle(fontFamily: _cuerpo, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        labelStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 13),
        border: OutlineInputBorder(borderRadius: radio, borderSide: BorderSide(color: cs.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: radio, borderSide: BorderSide(color: cs.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: radio, borderSide: BorderSide(color: cs.primary, width: 1.6)),
        errorBorder: OutlineInputBorder(borderRadius: radio, borderSide: BorderSide(color: cs.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: radio, borderSide: BorderSide(color: cs.error, width: 1.6)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radio),
      ),
      dividerTheme: DividerThemeData(color: cs.outlineVariant, space: 1),
    );
  }
}
