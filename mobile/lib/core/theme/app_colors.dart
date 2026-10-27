import 'package:flutter/material.dart';

/// Colores del sistema de diseño de AC-Master (tokens.json del prototipo).
abstract final class AcPalette {
  static const primary = Color(0xFF0F7783);
  static const background = Color(0xFFF5FBFC);
  static const foreground = Color(0xFF102A43);
  static const border = Color(0xFFD8EDEF);
  static const card = Color(0xFFFFFFFF);
  static const secondary = Color(0xFFE2F5F5);
  static const muted = Color(0xFFE8F7F6);
  static const mutedForeground = Color(0xFF5D7D87);
  static const accent = Color(0xFFFFF0E7);
  static const accentForeground = Color(0xFFC26338);
  static const destructive = Color(0xFFC45138);
  static const ring = Color(0xFF61AEB1);

  static const darkBackground = Color(0xFF0B2D39);
  static const darkForeground = Color(0xFFF4FBFB);
  static const darkBorder = Color(0xFF2B5963);
  static const darkCard = Color(0xFF123F4D);
  static const darkPrimary = Color(0xFF6DD4D2);
  static const darkPrimaryForeground = Color(0xFF07252E);
  static const darkSecondary = Color(0xFF1B5663);
  static const darkMuted = Color(0xFF173F4D);
  static const darkMutedForeground = Color(0xFFABD0D1);
  static const darkAccent = Color(0xFF6D4030);
  static const darkAccentForeground = Color(0xFFFFE7D9);
  static const darkDestructive = Color(0xFFED7655);
}

/// Tonos complementarios que no caben en ColorScheme: chips de estado y el bloque oscuro de portada.
@immutable
class AcColors extends ThemeExtension<AcColors> {
  const AcColors({
    required this.hero,
    required this.heroForeground,
    required this.heroMuted,
    required this.label,
    required this.tealBg,
    required this.tealFg,
    required this.orangeBg,
    required this.orangeFg,
    required this.blueBg,
    required this.blueFg,
    required this.greenBg,
    required this.greenFg,
  });

  final Color hero;
  final Color heroForeground;
  final Color heroMuted;
  final Color label;
  final Color tealBg;
  final Color tealFg;
  final Color orangeBg;
  final Color orangeFg;
  final Color blueBg;
  final Color blueFg;
  final Color greenBg;
  final Color greenFg;

  static const light = AcColors(
    hero: Color(0xFF123B4B),
    heroForeground: Colors.white,
    heroMuted: Color(0xFFC5E2E4),
    label: Color(0xFF4B7480),
    tealBg: Color(0xFFE2F5F5),
    tealFg: Color(0xFF0F7783),
    orangeBg: Color(0xFFFFF0E7),
    orangeFg: Color(0xFFC26338),
    blueBg: Color(0xFFE8F0FF),
    blueFg: Color(0xFF416AA8),
    greenBg: Color(0xFFE9F7ED),
    greenFg: Color(0xFF3D8B55),
  );

  static const dark = AcColors(
    hero: Color(0xFF092631),
    heroForeground: Color(0xFFF4FBFB),
    heroMuted: Color(0xFFABD0D1),
    label: Color(0xFFABD0D1),
    tealBg: Color(0xFF1B5663),
    tealFg: Color(0xFF6DD4D2),
    orangeBg: Color(0xFF6D4030),
    orangeFg: Color(0xFFFFE7D9),
    blueBg: Color(0xFF243E63),
    blueFg: Color(0xFF7CA9E8),
    greenBg: Color(0xFF244A33),
    greenFg: Color(0xFFA9D978),
  );

  @override
  AcColors copyWith() => this;

  @override
  AcColors lerp(AcColors? other, double t) {
    if (other == null) return this;
    return AcColors(
      hero: Color.lerp(hero, other.hero, t)!,
      heroForeground: Color.lerp(heroForeground, other.heroForeground, t)!,
      heroMuted: Color.lerp(heroMuted, other.heroMuted, t)!,
      label: Color.lerp(label, other.label, t)!,
      tealBg: Color.lerp(tealBg, other.tealBg, t)!,
      tealFg: Color.lerp(tealFg, other.tealFg, t)!,
      orangeBg: Color.lerp(orangeBg, other.orangeBg, t)!,
      orangeFg: Color.lerp(orangeFg, other.orangeFg, t)!,
      blueBg: Color.lerp(blueBg, other.blueBg, t)!,
      blueFg: Color.lerp(blueFg, other.blueFg, t)!,
      greenBg: Color.lerp(greenBg, other.greenBg, t)!,
      greenFg: Color.lerp(greenFg, other.greenFg, t)!,
    );
  }
}

extension AcColorsContext on BuildContext {
  AcColors get acColors => Theme.of(this).extension<AcColors>()!;
}
