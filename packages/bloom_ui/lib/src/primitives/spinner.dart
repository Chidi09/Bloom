// lib/src/primitives/spinner.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomSpinner extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;

  const BloomSpinner({
    super.key,
    this.size = 20.0,
    this.strokeWidth = 2.5,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation(color ?? context.bloomColors.primary),
      ),
    );
  }
}
