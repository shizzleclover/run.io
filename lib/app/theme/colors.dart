import 'package:flutter/material.dart';

/// One set of base colours per brightness.
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.elevated,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.cardTop,
  });

  final Brightness brightness;
  final Color bg;
  final Color surface;
  final Color elevated;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color textMuted;

  /// Top of the run card gradient. The bottom is [bg].
  final Color cardTop;

  // Flat neutrals, faintly cool. Separation comes from tone and spacing,
  // not borders and glows; [border] is for hairlines only.
  static const dark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF0E0F12),
    surface: Color(0xFF17191D),
    elevated: Color(0xFF212328),
    border: Color(0xFF2A2D33),
    text: Color(0xFFF4F4F5),
    textSecondary: Color(0xFF9CA0A8),
    textMuted: Color(0xFF63676F),
    cardTop: Color(0xFF17191D),
  );

  static const light = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF6F6F4),
    surface: Color(0xFFFFFFFF),
    elevated: Color(0xFFEDEDEA),
    border: Color(0xFFE4E4E0),
    text: Color(0xFF111214),
    textSecondary: Color(0xFF5E626A),
    textMuted: Color(0xFF969AA2),
    cardTop: Color(0xFFFFFFFF),
  );
}

class AppColors {
  AppColors._();

  /// Swapped by RunIoApp when the theme changes. The whole tree is rebuilt
  /// after a swap, so the getters below are always current.
  static AppPalette palette = AppPalette.dark;

  static bool get isDark => palette.brightness == Brightness.dark;

  // Base
  static Color get bg => palette.bg;
  static Color get surface => palette.surface;
  static Color get elevated => palette.elevated;
  static Color get border => palette.border;

  // Text
  static Color get text => palette.text;
  static Color get textSecondary => palette.textSecondary;
  static Color get textMuted => palette.textMuted;

  /// The run.io brand colour: buttons, highlights, the selected tab.
  /// Player colours are only for territory, trails and avatar rings.
  static const accent = Color(0xFFFF5A1F);

  // Semantic
  static const danger = Color(0xFFF04438);
  static const warning = Color(0xFFF5A524);
  static const ok = Color(0xFF2BB673);

  /// Text and icons on the accent or a player colour.
  static const onAccent = Color(0xFFFFFFFF);

  /// Player colours: clear "jersey" colours rather than neon, distinct from
  /// each other on both the dark and the light map. Orange (the brand) is
  /// first, so it's the default.
  static const playerColors = <int>[
    0xFFFF5A1F, // signal orange
    0xFF3B82F6, // blue
    0xFF22B573, // green
    0xFFA855F7, // violet
    0xFFEC4899, // pink
    0xFF14B8C4, // teal
  ];

  /// Saves from before the restyle hold the old neon colours. Each maps to
  /// the new colour in the same slot.
  static int migrateColor(int argb) => _legacy[argb] ?? argb;

  static const _legacy = <int, int>{
    0xFF3DFF8A: 0xFF22B573, // electric green
    0xFFFF3D9A: 0xFFEC4899, // hot pink
    0xFF3DD8FF: 0xFF14B8C4, // cyan
    0xFFFFB83D: 0xFFFF5A1F, // amber
    0xFF9A6BFF: 0xFFA855F7, // violet
    0xFFFF6B4A: 0xFF3B82F6, // coral, too close to the new orange
  };

  /// A player colour used as text or an icon. The neon colours wash out on
  /// light backgrounds, so they're darkened there.
  static Color ink(Color c) {
    if (isDark) return c;
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness * 0.62).clamp(0.0, 1.0)).toColor();
  }

  /// "#3DFF8A" for Mapbox style expressions.
  static String hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// "rgba(61,255,138,0.15)" for gradients.
  static String rgba(int argb, double alpha) {
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    return 'rgba($r,$g,$b,$alpha)';
  }
}
