// lib/src/primitives/separator.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomSeparator extends StatelessWidget {
  final Orientation orientation;
  final double? thickness;
  final EdgeInsetsGeometry? margin;

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
