// lib/src/utils/extensions.dart
import 'package:flutter/widgets.dart';
import '../theme/bloom_color_scheme.dart';
import '../theme/bloom_theme.dart';
import '../theme/bloom_theme_provider.dart';
import '../theme/tokens.dart';

/// Convenience extensions on [BuildContext] for accessing Bloom UI design tokens.
extension BloomBuildContext on BuildContext {
  /// Resolves the active [BloomTheme] from the nearest [BloomThemeProvider] ancestor,
  /// or falls back to the globally-selected style resolved against the platform brightness.
  BloomTheme get bloomTheme {
    final providerTheme = BloomThemeProvider.maybeOf(this);
    if (providerTheme != null) return providerTheme;
    final brightness = MediaQuery.maybeOf(this)?.platformBrightness ?? Brightness.light;
    return BloomTheme.resolve(brightness);
  }

  /// Direct shorthand for `context.bloomTheme.colors`.
  BloomColorScheme get bloomColors => bloomTheme.colors;

  /// Direct shorthand for `context.bloomTheme.radius`.
  BloomRadius get bloomRadius => bloomTheme.radius;

  /// Direct shorthand for `context.bloomTheme.spacing`.
  BloomSpacing get bloomSpacing => bloomTheme.spacing;

  /// Direct shorthand for `context.bloomTheme.typography`.
  BloomTypography get bloomTypography => bloomTheme.typography;
}
