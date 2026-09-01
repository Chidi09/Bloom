// lib/src/theme/bloom_theme_provider.dart
import 'package:flutter/widgets.dart';

import 'bloom_theme.dart';

/// Provides a [BloomTheme] to the widget subtree without any Material dependency.
///
/// Descendant widgets can read the active theme via [BloomThemeProvider.of] or
/// the `context.bloomTheme` extension.
///
/// ## Usage
/// ```dart
/// BloomThemeProvider(
///   theme: BloomTheme.novaLight,
///   child: const MyWidget(),
/// );
/// ```
class BloomThemeProvider extends InheritedWidget {
  /// Creates a [BloomThemeProvider] exposing [theme] to descendants.
  const BloomThemeProvider({
    super.key,
    required this.theme,
    required super.child,
  });

  /// The theme exposed to descendants.
  final BloomTheme theme;

  /// The nearest [BloomTheme], or null when no provider is above [context].
  static BloomTheme? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BloomThemeProvider>()?.theme;

  /// The nearest [BloomTheme]. Throws a [FlutterError] when absent.
  static BloomTheme of(BuildContext context) {
    final theme = maybeOf(context);
    if (theme != null) {
      return theme;
    }
    throw FlutterError.fromParts(<DiagnosticsNode>[
      ErrorSummary('No BloomThemeProvider found in context.'),
      ErrorDescription(
        'Bloom UI widgets require a BloomThemeProvider ancestor '
        'to supply theme tokens like colors, typography, spacing, and radius.',
      ),
      ErrorHint(
        'Make sure your widget tree is wrapped with BloomApp or BloomThemeProvider:\n'
        '  BloomApp(\n'
        '    theme: BloomTheme.novaLight,\n'
        '    home: ...,\n'
        '  )',
      ),
    ]);
  }

  @override
  bool updateShouldNotify(BloomThemeProvider oldWidget) => oldWidget.theme != theme;
}
