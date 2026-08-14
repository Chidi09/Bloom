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
  final Color muted;
  final Color mutedForeground;
  final Color accent;
  final Color accentForeground;
  final Color destructive;
  final Color destructiveForeground;
  final Color surface0;
  final Color surface1;
  final Color surface2;
  final Color border;
  final Color buttonBorder;
  final Color ring;
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
    this.muted = const Color(0xFFF5F5F5),
    this.mutedForeground = const Color(0xFF737373),
    this.accent = const Color(0xFFF5F5F5),
    this.accentForeground = const Color(0xFF171717),
    required this.destructive,
    required this.destructiveForeground,
    required this.surface0,
    required this.surface1,
    required this.surface2,
    required this.border,
    this.buttonBorder = const Color(0xFFE5E5E5),
    this.ring = const Color(0xFFA1A1A1),
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    this.chart1 = const Color(0xFFF54900),
    this.chart2 = const Color(0xFF009689),
    this.chart3 = const Color(0xFF104E64),
    this.chart4 = const Color(0xFFFFB900),
    this.chart5 = const Color(0xFFFE9A00),
  });

  /// Default theme matching shadcn/ui (base-nova) neutral palette exactly.
  /// Converted from shipped oklch values via exact oklch→sRGB conversion.
  static const BloomColorScheme light = BloomColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF171717),
    primaryForeground: Color(0xFFFAFAFA),
    secondary: Color(0xFFF5F5F5),
    secondaryForeground: Color(0xFF171717),
    destructive: Color(0xFFE7000B),
    destructiveForeground: Color(0xFFFAFAFA),
    surface0: Color(0xFFFAFAFA),
    surface1: Color(0xFFFFFFFF),
    surface2: Color(0xFFF5F5F5),
    border: Color(0xFFE5E5E5),
    buttonBorder: Color(0xFFE5E5E5),
    ring: Color(0xFFA1A1A1),
    textPrimary: Color(0xFF0A0A0A),
    textSecondary: Color(0xFF737373),
    textTertiary: Color(0xFFA1A1A1),
    success: Color(0xFF16A34A),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFE7000B),
    info: Color(0xFF2563EB),
    chart1: Color(0xFFF54900),
    chart2: Color(0xFF009689),
    chart3: Color(0xFF104E64),
    chart4: Color(0xFFFFB900),
    chart5: Color(0xFFFE9A00),
  );

  static const BloomColorScheme dark = BloomColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFE5E5E5),
    primaryForeground: Color(0xFF171717),
    secondary: Color(0xFF262626),
    secondaryForeground: Color(0xFFFAFAFA),
    muted: Color(0xFF262626),
    mutedForeground: Color(0xFFA1A1A1),
    accent: Color(0xFF262626),
    accentForeground: Color(0xFFFAFAFA),
    destructive: Color(0xFFFF6467),
    destructiveForeground: Color(0xFFFAFAFA),
    surface0: Color(0xFF0A0A0A),
    surface1: Color(0xFF171717),
    surface2: Color(0xFF262626),
    border: Color(0xFF222222),
    buttonBorder: Color(0xFF222222),
    ring: Color(0xFF737373),
    textPrimary: Color(0xFFFAFAFA),
    textSecondary: Color(0xFFA1A1A1),
    textTertiary: Color(0xFF737373),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFFF6467),
    info: Color(0xFF60A5FA),
    chart1: Color(0xFF1447E6),
    chart2: Color(0xFF00BC7D),
    chart3: Color(0xFFFE9A00),
    chart4: Color(0xFFAD46FF),
    chart5: Color(0xFFFF2056),
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
    buttonBorder: BloomColors.borderSubtleLight,
    ring: Color(0xFF94A3B8),
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
    buttonBorder: BloomColors.borderSubtleDark,
    ring: Color(0xFF64748B),
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
    Color? muted,
    Color? mutedForeground,
    Color? accent,
    Color? accentForeground,
    Color? buttonBorder,
    Color? ring,
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
      muted: muted ?? this.muted,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      accent: accent ?? this.accent,
      accentForeground: accentForeground ?? this.accentForeground,
      destructive: destructive ?? this.destructive,
      destructiveForeground: destructiveForeground ?? this.destructiveForeground,
      surface0: surface0 ?? this.surface0,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      border: border ?? this.border,
      buttonBorder: buttonBorder ?? this.buttonBorder,
      ring: ring ?? this.ring,
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
    Color l(Color x, Color y) => Color.lerp(x, y, t)!;
    return BloomColorScheme(
      brightness: t < 0.5 ? a.brightness : b.brightness,
      primary: l(a.primary, b.primary),
      primaryForeground: l(a.primaryForeground, b.primaryForeground),
      secondary: l(a.secondary, b.secondary),
      secondaryForeground: l(a.secondaryForeground, b.secondaryForeground),
      muted: l(a.muted, b.muted),
      mutedForeground: l(a.mutedForeground, b.mutedForeground),
      accent: l(a.accent, b.accent),
      accentForeground: l(a.accentForeground, b.accentForeground),
      destructive: l(a.destructive, b.destructive),
      destructiveForeground: l(a.destructiveForeground, b.destructiveForeground),
      surface0: l(a.surface0, b.surface0),
      surface1: l(a.surface1, b.surface1),
      surface2: l(a.surface2, b.surface2),
      border: l(a.border, b.border),
      buttonBorder: l(a.buttonBorder, b.buttonBorder),
      ring: l(a.ring, b.ring),
      textPrimary: l(a.textPrimary, b.textPrimary),
      textSecondary: l(a.textSecondary, b.textSecondary),
      textTertiary: l(a.textTertiary, b.textTertiary),
      success: l(a.success, b.success),
      warning: l(a.warning, b.warning),
      error: l(a.error, b.error),
      info: Color.lerp(a.info, b.info, t)!,
      chart1: Color.lerp(a.chart1, b.chart1, t)!,
      chart2: Color.lerp(a.chart2, b.chart2, t)!,
      chart3: Color.lerp(a.chart3, b.chart3, t)!,
      chart4: Color.lerp(a.chart4, b.chart4, t)!,
      chart5: Color.lerp(a.chart5, b.chart5, t)!,
    );
  }
}
