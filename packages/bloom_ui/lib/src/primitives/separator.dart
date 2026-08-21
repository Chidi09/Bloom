// lib/src/primitives/separator.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

/// A visual divider or rule used to separate sections of content horizontally or vertically.
///
/// Adapts its dimensions and margins based on [orientation], rendering a subtle border
/// using the theme's [BloomColorScheme.border] color.
///
/// ```dart
/// // Horizontal separator (default)
/// BloomSeparator();
///
/// // Vertical separator inside a row
/// Row(
///   children: [
///     Text('Left'),
///     BloomSeparator(orientation: Orientation.portrait),
///     Text('Right'),
///   ],
/// );
/// ```
class BloomSeparator extends StatelessWidget {
  /// The layout orientation of the separator.
  ///
  /// When set to [Orientation.landscape], renders horizontally across full available width.
  /// When set to [Orientation.portrait], renders vertically along full available height.
  /// Defaults to [Orientation.landscape].
  final Orientation orientation;

  /// The line thickness in logical pixels.
  ///
  /// Defaults to `1.0`.
  final double? thickness;

  /// The outer margin surrounding the separator line.
  ///
  /// If null, defaults to `EdgeInsets.symmetric(vertical: 8)` for horizontal separators
  /// and `EdgeInsets.symmetric(horizontal: 8)` for vertical separators.
  final EdgeInsetsGeometry? margin;

  /// Creates a [BloomSeparator].
  const BloomSeparator({
    super.key,
    this.orientation = Orientation.landscape,
    this.thickness = 1.0,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    if (orientation == Orientation.portrait) {
      return Container(
        margin: margin ?? const EdgeInsets.symmetric(horizontal: 8),
        width: thickness,
        color: colors.border,
      );
    }

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
      height: thickness,
      color: colors.border,
    );
  }
}
