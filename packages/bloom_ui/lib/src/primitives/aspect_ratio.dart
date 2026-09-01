// lib/src/primitives/aspect_ratio.dart
import 'package:flutter/widgets.dart';

/// A layout container that sizes its [child] to a specific aspect ratio with optional border radius clipping.
///
/// Combines Flutter's [AspectRatio] and [ClipRRect] into a single clean primitive.
///
/// ```dart
/// BloomAspectRatio(
///   aspectRatio: 16 / 9,
///   borderRadius: BorderRadius.circular(8),
///   child: Image.network('https://example.com/cover.jpg', fit: BoxFit.cover),
/// );
/// ```
class BloomAspectRatio extends StatelessWidget {
  /// The aspect ratio to enforce, expressed as a ratio of width to height (e.g. `16 / 9` or `4 / 3`).
  final double aspectRatio;

  /// The child widget to display inside the aspect-ratio-constrained box.
  final Widget child;

  /// Optional border radius used to clip the contents via [ClipRRect].
  final BorderRadius? borderRadius;

  /// Creates a [BloomAspectRatio].
  ///
  /// The [aspectRatio] and [child] parameters are required.
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
