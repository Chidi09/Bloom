// lib/src/theme/bloom_theme.dart
import 'package:flutter/widgets.dart';
import 'bloom_color_scheme.dart';
import 'tokens.dart';

/// The eight official shadcn/ui component styles.
enum BloomThemeStyle {
  nova,
  vega,
  maia,
  lyra,
  mira,
  luma,
  sera,
  rhea,
}

/// Standalone immutable theme carrying the full Bloom Token & Component Theme,
/// provided through `BloomThemeProvider`.
///
/// Shadcn/ui defines 8 official styles that change radius, spacing,
/// density and typography without changing component code:
///   nova (default, compact), vega (classic balanced), maia (soft large),
///   lyra (sharp zero-radius), mira (ultra-compact), luma (balanced refined),
///   sera (editorial serif), rhea (smooth modern).
@immutable
class BloomTheme {
  final BloomColorScheme colors;
  final BloomSpacing spacing;
  final BloomRadius radius;
  final BloomTypography typography;

  const BloomTheme({
    required this.colors,
    this.spacing = const BloomSpacing(),
    this.radius = const BloomRadius(),
    this.typography = const BloomTypography(),
  });

  // -- Shadcn Style Presets (neutral base) --

  /// Nova (default): tighter spacing, compact, Geist sans, 10px base radius.
  static const BloomTheme novaLight = BloomTheme(
    colors: BloomColorScheme.light,
    spacing: BloomSpacing(s4: 12, s5: 20, s6: 28),
    radius: BloomRadius(sm: 6, md: 8, lg: 10, xl: 14),
    typography: BloomTypography(sans: 'Geist', mono: 'GeistMono', sm: 13, base: 14),
  );
  static const BloomTheme novaDark = BloomTheme(
    colors: BloomColorScheme.dark,
    spacing: BloomSpacing(s4: 12, s5: 20, s6: 28),
    radius: BloomRadius(sm: 6, md: 8, lg: 10, xl: 14),
    typography: BloomTypography(sans: 'Geist', mono: 'GeistMono', sm: 13, base: 14),
  );

  /// Vega (classic "New York"): medium radius, balanced spacing, Geist sans.
  static const BloomTheme vegaLight = BloomTheme(
    colors: BloomColorScheme.light,
    spacing: BloomSpacing(),
    radius: BloomRadius(sm: 8, md: 12, lg: 16, xl: 24),
    typography: BloomTypography(sans: 'Geist', mono: 'GeistMono', sm: 14, base: 16),
  );
  static const BloomTheme vegaDark = BloomTheme(
    colors: BloomColorScheme.dark,
    spacing: BloomSpacing(),
    radius: BloomRadius(sm: 8, md: 12, lg: 16, xl: 24),
    typography: BloomTypography(sans: 'Geist', mono: 'GeistMono', sm: 14, base: 16),
  );

  /// Maia: larger softer radii, generous spacing.
  static const BloomTheme maiaLight = BloomTheme(
    colors: BloomColorScheme.light,
    spacing: BloomSpacing(s4: 20, s5: 32, s6: 40),
    radius: BloomRadius(sm: 12, md: 16, lg: 20, xl: 32),
    typography: BloomTypography(sans: 'Geist', mono: 'GeistMono', sm: 14, base: 16),
  );
  static const BloomTheme maiaDark = BloomTheme(
    colors: BloomColorScheme.dark,
    spacing: BloomSpacing(s4: 20, s5: 32, s6: 40),
    radius: BloomRadius(sm: 12, md: 16, lg: 20, xl: 32),
    typography: BloomTypography(sans: 'Geist', mono: 'GeistMono', sm: 14, base: 16),
  );

  /// Lyra: sharp, boxy, zero border radius.
  static const BloomTheme lyraLight = BloomTheme(
    colors: BloomColorScheme.light,
    spacing: BloomSpacing(),
    radius: BloomRadius(sm: 0, md: 0, lg: 0, xl: 0),
    typography: BloomTypography(sans: 'Geist', mono: 'GeistMono', sm: 14, base: 16),
  );
  static const BloomTheme lyraDark = BloomTheme(
    colors: BloomColorScheme.dark,
    spacing: BloomSpacing(),
    radius: BloomRadius(sm: 0, md: 0, lg: 0, xl: 0),
    typography: BloomTypography(sans: 'Geist', mono: 'GeistMono', sm: 14, base: 16),
  );

  /// Mira: ultra-compact spacing and tighter type.
  static const BloomTheme miraLight = BloomTheme(
    colors: BloomColorScheme.light,
    spacing: BloomSpacing(s1: 2, s2: 4, s3: 8, s4: 10, s5: 16),
    radius: BloomRadius(sm: 4, md: 6, lg: 8, xl: 12),
    typography: BloomTypography(sans: 'Geist', mono: 'GeistMono', xs: 11, sm: 12, base: 13),
  );
  static const BloomTheme miraDark = BloomTheme(
    colors: BloomColorScheme.dark,
    spacing: BloomSpacing(s1: 2, s2: 4, s3: 8, s4: 10, s5: 16),
    radius: BloomRadius(sm: 4, md: 6, lg: 8, xl: 12),
    typography: BloomTypography(sans: 'Geist', mono: 'GeistMono', xs: 11, sm: 12, base: 13),
  );

  /// Luma: balanced layout with refined visual harmony.
  static const BloomTheme lumaLight = BloomTheme(
    colors: BloomColorScheme.light,
    spacing: BloomSpacing(s4: 14, s5: 22, s6: 30),
    radius: BloomRadius(sm: 6, md: 10, lg: 14, xl: 20),
    typography: BloomTypography(sans: 'Geist', mono: 'GeistMono', sm: 14, base: 16),
  );
  static const BloomTheme lumaDark = BloomTheme(
    colors: BloomColorScheme.dark,
    spacing: BloomSpacing(s4: 14, s5: 22, s6: 30),
    radius: BloomRadius(sm: 6, md: 10, lg: 14, xl: 20),
    typography: BloomTypography(sans: 'Geist', mono: 'GeistMono', sm: 14, base: 16),
  );

  /// Sera: editorial-focused with serif body.
  static const BloomTheme seraLight = BloomTheme(
    colors: BloomColorScheme.light,
    spacing: BloomSpacing(),
    radius: BloomRadius(sm: 2, md: 4, lg: 8, xl: 12),
    typography: BloomTypography(sans: 'SourceSerif4', mono: 'GeistMono', sm: 15, base: 18),
  );
  static const BloomTheme seraDark = BloomTheme(
    colors: BloomColorScheme.dark,
    spacing: BloomSpacing(),
    radius: BloomRadius(sm: 2, md: 4, lg: 8, xl: 12),
    typography: BloomTypography(sans: 'SourceSerif4', mono: 'GeistMono', sm: 15, base: 18),
  );

  /// Rhea: smooth modern with generous curves.
  static const BloomTheme rheaLight = BloomTheme(
    colors: BloomColorScheme.light,
    spacing: BloomSpacing(s4: 18, s5: 28, s6: 36),
    radius: BloomRadius(sm: 10, md: 14, lg: 18, xl: 28),
    typography: BloomTypography(sans: 'Geist', mono: 'GeistMono', sm: 14, base: 16),
  );
  static const BloomTheme rheaDark = BloomTheme(
    colors: BloomColorScheme.dark,
    spacing: BloomSpacing(s4: 18, s5: 28, s6: 36),
    radius: BloomRadius(sm: 10, md: 14, lg: 18, xl: 28),
    typography: BloomTypography(sans: 'Geist', mono: 'GeistMono', sm: 14, base: 16),
  );

  // -- Legacy compat (Nova default) --

  /// Default light theme — Nova style, neutral base.
  static const BloomTheme light = BloomTheme(
    colors: BloomColorScheme.light,
    spacing: BloomSpacing(s4: 12, s5: 20, s6: 28),
    radius: BloomRadius(sm: 6, md: 8, lg: 10, xl: 14),
    typography: BloomTypography(sans: 'Geist', mono: 'GeistMono', sm: 13, base: 14),
  );

  /// Default dark theme — Nova style, neutral base.
  static const BloomTheme dark = BloomTheme(
    colors: BloomColorScheme.dark,
    spacing: BloomSpacing(s4: 12, s5: 20, s6: 28),
    radius: BloomRadius(sm: 6, md: 8, lg: 10, xl: 14),
    typography: BloomTypography(sans: 'Geist', mono: 'GeistMono', sm: 13, base: 14),
  );

  static BloomThemeStyle _currentStyle = BloomThemeStyle.nova;
  static BloomThemeStyle get currentStyle => _currentStyle;
  static void setStyle(BloomThemeStyle style) {
    _currentStyle = style;
  }

  /// Resolve a theme by the globally-selected style and a [Brightness].
  static BloomTheme resolve(Brightness brightness) {
    return switch (_currentStyle) {
      BloomThemeStyle.nova => brightness == Brightness.dark ? novaDark : novaLight,
      BloomThemeStyle.vega => brightness == Brightness.dark ? vegaDark : vegaLight,
      BloomThemeStyle.maia => brightness == Brightness.dark ? maiaDark : maiaLight,
      BloomThemeStyle.lyra => brightness == Brightness.dark ? lyraDark : lyraLight,
      BloomThemeStyle.mira => brightness == Brightness.dark ? miraDark : miraLight,
      BloomThemeStyle.luma => brightness == Brightness.dark ? lumaDark : lumaLight,
      BloomThemeStyle.sera => brightness == Brightness.dark ? seraDark : seraLight,
      BloomThemeStyle.rhea => brightness == Brightness.dark ? rheaDark : rheaLight,
    };
  }

  BloomTheme copyWith({
    BloomColorScheme? colors,
    BloomSpacing? spacing,
    BloomRadius? radius,
    BloomTypography? typography,
  }) {
    return BloomTheme(
      colors: colors ?? this.colors,
      spacing: spacing ?? this.spacing,
      radius: radius ?? this.radius,
      typography: typography ?? this.typography,
    );
  }

  BloomTheme lerp(BloomTheme? other, double t) {
    if (other == null) return this;
    return BloomTheme(
      colors: BloomColorScheme.lerp(colors, other.colors, t),
      spacing: spacing,
      radius: radius,
      typography: typography,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BloomTheme &&
          runtimeType == other.runtimeType &&
          colors == other.colors &&
          spacing == other.spacing &&
          radius == other.radius &&
          typography == other.typography;

  @override
  int get hashCode => Object.hash(colors, spacing, radius, typography);
}
