import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// One family, Inter Tight, for everything. Hierarchy comes from size and
/// weight, and numbers use tabular figures so they don't jitter as they
/// tick.
class AppText {
  AppText._();

  static TextStyle _base({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double letterSpacing = 0,
  }) => GoogleFonts.interTight(
    fontSize: size,
    fontWeight: weight,
    color: color ?? AppColors.text,
    height: height,
    letterSpacing: letterSpacing,
  );

  static TextStyle number(double size, {Color? color}) => _base(
    size: size,
    weight: FontWeight.w600,
    color: color,
    height: 1.0,
    letterSpacing: -size * 0.03,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  static TextStyle unit(double size) => _base(
    size: size,
    weight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static TextStyle title(double size, {Color? color}) => _base(
    size: size,
    weight: FontWeight.w600,
    color: color,
    height: 1.15,
    letterSpacing: -size * 0.02,
  );

  /// Small sentence-case caption above or below a value: "Owned".
  static TextStyle get label =>
      _base(size: 13, weight: FontWeight.w500, color: AppColors.textSecondary);

  /// Section heading inside a screen: "This week", "Following".
  static TextStyle get section =>
      _base(size: 17, weight: FontWeight.w600, letterSpacing: -0.2);

  static TextStyle get body => _base(size: 15, height: 1.4);

  static TextStyle get bodyMuted =>
      _base(size: 15, color: AppColors.textSecondary, height: 1.4);

  static TextStyle get small =>
      _base(size: 13, color: AppColors.textSecondary, height: 1.3);
}

/// Corner radii, so screens agree with each other.
class AppRadius {
  AppRadius._();
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
}

/// Spacing scale. Every gap and padding in the app is one of these.
class AppSpace {
  AppSpace._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const section = 36.0;

  /// Left/right padding of every screen.
  static const screen = 20.0;
}

/// Standard sizes, so the same thing is the same size everywhere.
class AppSize {
  AppSize._();
  static const icon = 22.0;
  static const iconSm = 18.0;
  static const avatarSm = 32.0;
  static const avatar = 40.0;
  static const avatarLg = 72.0;
  static const button = 52.0;
  static const mapButton = 48.0;
  static const startButton = 88.0;
}

/// Motion: three speeds and one curve, used everywhere.
class AppMotion {
  AppMotion._();
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 450);

  /// Quick start, soft landing.
  static const curve = Curves.easeOutCubic;
}

ThemeData buildTheme(AppPalette p) {
  final dark = p.brightness == Brightness.dark;
  final base = ThemeData(brightness: p.brightness, useMaterial3: true);
  final scheme = dark ? const ColorScheme.dark() : const ColorScheme.light();
  final pill = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    splashFactory: InkSparkle.splashFactory,
    colorScheme: scheme.copyWith(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      surfaceContainerHighest: AppColors.elevated,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      error: AppColors.danger,
    ),
    textTheme: GoogleFonts.interTightTextTheme(
      base.textTheme,
    ).apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.title(20),
      systemOverlayStyle: overlayStyle(p),
    ),
    dividerColor: AppColors.border,
    dividerTheme: DividerThemeData(
      color: AppColors.border,
      space: 1,
      thickness: 0.5,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      titleTextStyle: AppText.body,
      subtitleTextStyle: AppText.small,
      iconColor: AppColors.textSecondary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: AppText.body.copyWith(fontWeight: FontWeight.w600),
        shape: pill,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        side: BorderSide(color: AppColors.border),
        textStyle: AppText.body.copyWith(fontWeight: FontWeight.w600),
        shape: pill,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: AppText.body.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.elevated
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.text
              : AppColors.textSecondary,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
        textStyle: WidgetStatePropertyAll(
          AppText.small.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.onAccent
            : AppColors.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.accent
            : AppColors.elevated,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.accent,
      thumbColor: AppColors.accent,
      inactiveTrackColor: AppColors.border,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: AppColors.border,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? AppColors.elevated : const Color(0xFF1B1C1F),
      contentTextStyle: AppText.body.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.elevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: AppColors.accent.withValues(alpha: 0.3),
      selectionHandleColor: AppColors.accent,
    ),
    // Pages fade and drift forward instead of the default hard slide.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
  );
}

/// Status and nav bar icons that contrast with the palette.
SystemUiOverlayStyle overlayStyle(AppPalette p) {
  final dark = p.brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: p.brightness,
    // Same as the tab bar, so the system buttons don't sit on a white strip.
    systemNavigationBarColor: p.bg,
    systemNavigationBarDividerColor: p.bg,
    systemNavigationBarContrastEnforced: false,
    systemNavigationBarIconBrightness: dark
        ? Brightness.light
        : Brightness.dark,
  );
}
