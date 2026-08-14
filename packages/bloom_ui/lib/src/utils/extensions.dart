// lib/src/utils/extensions.dart
import 'package:flutter/material.dart';
import '../theme/bloom_color_scheme.dart';
import '../theme/bloom_theme.dart';
import '../theme/tokens.dart';

extension BloomBuildContext on BuildContext {
  /// Resolves the active [BloomTheme] from the widget tree or falls back to light/dark defaults.
  BloomTheme get bloomTheme {
    final ext = Theme.of(this).extension<BloomTheme>();
    if (ext != null) return ext;
    final isDark = Theme.of(this).brightness == Brightness.dark;
    return isDark ? BloomTheme.dark : BloomTheme.light;
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
