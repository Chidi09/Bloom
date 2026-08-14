// lib/src/primitives/aspect_ratio.dart
import 'package:flutter/material.dart';

class BloomAspectRatio extends StatelessWidget {
  final double aspectRatio;
  final Widget child;
  final BorderRadius? borderRadius;

  const BloomAspectRatio({
    super.key,
    required this.aspectRatio,
    required this.child,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = AspectRatio(
      aspectRatio: aspectRatio,
      child: child,
    );

    if (borderRadius != null) {
      content = ClipRRect(borderRadius: borderRadius!, child: content);
    }

    return content;
  }
}
