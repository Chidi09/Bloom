// lib/src/theme/bloom_color_scheme.dart
import 'package:flutter/material.dart';
import 'tokens.dart';

/// Semantic Bloom Color Palette.
class BloomColorScheme {
  final Brightness brightness;
  final Color primary;
  final Color primaryForeground;
  final Color secondary;
  final Color secondaryForeground;
  final Color destructive;
  final Color destructiveForeground;
  final Color surface0;
  final Color surface1;
  final Color surface2;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color chart1;
  final Color chart2;
  final Color chart3;
  final Color chart4;
  final Color chart5;

  const BloomColorScheme({
    required this.brightness,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.destructive,
    required this.destructiveForeground,
    required this.surface0,
    required this.surface1,
    required this.surface2,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    this.chart1 = const Color(0xFF2563EB),
    this.chart2 = const Color(0xFF16A34A),
    this.chart3 = const Color(0xFFD97706),
    this.chart4 = const Color(0xFFDC2626),
    this.chart5 = const Color(0xFF9333EA),
  });

  /// Default theme matching shadcn/ui (new-york) neutral palette.
  static const BloomColorScheme light = BloomColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF09090B),
    primaryForeground: Color(0xFFFAFAFA),
    secondary: Color(0xFFF4F4F5),
    secondaryForeground: Color(0xFF18181B),
    destructive: Color(0xFFEF4444),
    destructiveForeground: Color(0xFFFAFAFA),
    surface0: Color(0xFFFAFAFA),
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFF4F4F5),
    border: Color(0xFFE4E4E7),
    textPrimary: Color(0xFF09090B),
    textSecondary: Color(0xFF52525B),
    textTertiary: Color(0xFFA1A1AA),
    success: Color(0xFF16A34A),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    info: Color(0xFF3B82F6),
    chart1: Color(0xFF2563EB),
    chart2: Color(0xFF16A34A),
    chart3: Color(0xFFD97706),
    chart4: Color(0xFFDC2626),
    chart5: Color(0xFF9333EA),
  );

  static const BloomColorScheme dark = BloomColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFAFAFA),
    primaryForeground: Color(0xFF18181B),
    secondary: Color(0xFF27272A),
    secondaryForeground: Color(0xFFFAFAFA),
    destructive: Color(0xFF7F1D1D),
    destructiveForeground: Color(0xFFFAFAFA),
    surface0: Color(0xFF09090B),
    surface1: Color(0xFF18181B),
    surface2: Color(0xFF27272A),
    border: Color(0xFF27272A),
    textPrimary: Color(0xFFFAFAFA),
    textSecondary: Color(0xFFA1A1AA),
    textTertiary: Color(0xFF71717A),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFF87171),
    info: Color(0xFF60A5FA),
    chart1: Color(0xFF60A5FA),
    chart2: Color(0xFF34D399),
    chart3: Color(0xFFFBBF24),
    chart4: Color(0xFFA78BFA),
    chart5: Color(0xFFF472B6),
  );

  /// Alternate opt-in theme preserving the original Bloom petal-brand palette.
  static const BloomColorScheme petalLight = BloomColorScheme(
    brightness: Brightness.light,
    primary: BloomColors.petalPurple,
    primaryForeground: Colors.white,
    secondary: Color(0xFFF1F5F9),
    secondaryForeground: Color(0xFF0F172A),
    destructive: BloomColors.error,
    destructiveForeground: Colors.white,
    surface0: BloomColors.surface0Light,
    surface1: BloomColors.surface1Light,
    surface2: BloomColors.surface2Light,
    border: BloomColors.borderSubtleLight,
    textPrimary: BloomColors.textPrimaryLight,
    textSecondary: BloomColors.textSecondaryLight,
    textTertiary: BloomColors.textTertiaryLight,
    success: BloomColors.success,
    warning: BloomColors.warning,
    error: BloomColors.error,
    info: BloomColors.info,
    chart1: BloomColors.petalBlue,
    chart2: BloomColors.success,
    chart3: BloomColors.warning,
    chart4: BloomColors.error,
    chart5: BloomColors.petalPurple,
  );

  static const BloomColorScheme petalDark = BloomColorScheme(
    brightness: Brightness.dark,
    primary: BloomColors.petalPurple,
    primaryForeground: Colors.white,
    secondary: Color(0xFF1E293B),
    secondaryForeground: Color(0xFFF8FAFC),
    destructive: BloomColors.error,
    destructiveForeground: Colors.white,
    surface0: BloomColors.surface0Dark,
    surface1: BloomColors.surface1Dark,
    surface2: BloomColors.surface2Dark,
    border: BloomColors.borderSubtleDark,
    textPrimary: BloomColors.textPrimaryDark,
    textSecondary: BloomColors.textSecondaryDark,
    textTertiary: BloomColors.textTertiaryDark,
    success: BloomColors.success,
    warning: BloomColors.warning,
    error: BloomColors.error,
    info: BloomColors.info,
    chart1: BloomColors.petalBlue,
    chart2: BloomColors.success,
    chart3: BloomColors.warning,
    chart4: BloomColors.error,
    chart5: BloomColors.petalPurple,
  );

  BloomColorScheme copyWith({
    Brightness? brightness,
    Color? primary,
    Color? primaryForeground,
    Color? secondary,
    Color? secondaryForeground,
    Color? destructive,
    Color? destructiveForeground,
    Color? surface0,
    Color? surface1,
    Color? surface2,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? chart1,
    Color? chart2,
    Color? chart3,
    Color? chart4,
    Color? chart5,
  }) {
    return BloomColorScheme(
      brightness: brightness ?? this.brightness,
      primary: primary ?? this.primary,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      secondary: secondary ?? this.secondary,
      secondaryForeground: secondaryForeground ?? this.secondaryForeground,
      destructive: destructive ?? this.destructive,
      destructiveForeground: destructiveForeground ?? this.destructiveForeground,
      surface0: surface0 ?? this.surface0,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      chart1: chart1 ?? this.chart1,
      chart2: chart2 ?? this.chart2,
      chart3: chart3 ?? this.chart3,
      chart4: chart4 ?? this.chart4,
      chart5: chart5 ?? this.chart5,
    );
  }

  static BloomColorScheme lerp(BloomColorScheme a, BloomColorScheme b, double t) {
    return BloomColorScheme(
      brightness: t < 0.5 ? a.brightness : b.brightness,
      primary: Color.lerp(a.primary, b.primary, t)!,
      primaryForeground: Color.lerp(a.primaryForeground, b.primaryForeground, t)!,
      secondary: Color.lerp(a.secondary, b.secondary, t)!,
      secondaryForeground: Color.lerp(a.secondaryForeground, b.secondaryForeground, t)!,
      destructive: Color.lerp(a.destructive, b.destructive, t)!,
      destructiveForeground: Color.lerp(a.destructiveForeground, b.destructiveForeground, t)!,
      surface0: Color.lerp(a.surface0, b.surface0, t)!,
      surface1: Color.lerp(a.surface1, b.surface1, t)!,
      surface2: Color.lerp(a.surface2, b.surface2, t)!,
      border: Color.lerp(a.border, b.border, t)!,
      textPrimary: Color.lerp(a.textPrimary, b.textPrimary, t)!,
      textSecondary: Color.lerp(a.textSecondary, b.textSecondary, t)!,
      textTertiary: Color.lerp(a.textTertiary, b.textTertiary, t)!,
      success: Color.lerp(a.success, b.success, t)!,
      warning: Color.lerp(a.warning, b.warning, t)!,
      error: Color.lerp(a.error, b.error, t)!,
      info: Color.lerp(a.info, b.info, t)!,
      chart1: Color.lerp(a.chart1, b.chart1, t)!,
      chart2: Color.lerp(a.chart2, b.chart2, t)!,
      chart3: Color.lerp(a.chart3, b.chart3, t)!,
      chart4: Color.lerp(a.chart4, b.chart4, t)!,
      chart5: Color.lerp(a.chart5, b.chart5, t)!,
    );
  }
}
