// lib/src/primitives/direction.dart
import 'package:flutter/material.dart';

/// Wraps content in an LTR or RTL text direction context, mirroring
/// shadcn/ui Direction support. Useful for reading-mode and i18n layouts.
class BloomDirection extends StatelessWidget {
  final TextDirection direction;
  final Widget child;

  const BloomDirection({super.key, required this.direction, required this.child});

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: direction, child: child);
  }
}
