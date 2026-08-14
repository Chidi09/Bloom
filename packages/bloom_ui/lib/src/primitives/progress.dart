// lib/src/primitives/progress.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomProgress extends StatelessWidget {
  final double? value;
  final double height;
  final Color? color;
  final Color? backgroundColor;

  const BloomProgress({
    super.key,
    required this.value,
    this.height = 6.0,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: value,
          valueColor: AlwaysStoppedAnimation(color ?? colors.primary),
          backgroundColor: backgroundColor ?? colors.secondary,
        ),
      ),
    );
  }
}
