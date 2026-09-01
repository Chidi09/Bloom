// lib/src/primitives/skeleton.dart
import 'package:flutter/widgets.dart';
import '../utils/extensions.dart';

/// An animated pulsing placeholder used to indicate loading state of UI elements.
///
/// Cycles opacity between `0.4` and `0.8` using [BloomColorScheme.secondary] over a 1200ms duration.
///
/// ```dart
/// // Rectangular skeleton with custom dimensions and radius
/// BloomSkeleton(
///   width: 200,
///   height: 20,
///   borderRadius: BorderRadius.circular(4),
/// );
///
/// // Circular avatar skeleton
/// BloomSkeleton.circle(size: 40);
/// ```
class BloomSkeleton extends StatefulWidget {
  /// The width of the skeleton placeholder box.
  ///
  /// If null, expands to fill the parent container.
  final double? width;

  /// The height of the skeleton placeholder box.
  ///
  /// If null, expands to fill the parent container.
  final double? height;

  /// The border radius applied when [shape] is [BoxShape.rectangle].
  ///
  /// Defaults to [BloomRadius.md] if unspecified.
  final BorderRadius? borderRadius;

  /// The shape of the skeleton box ([BoxShape.rectangle] or [BoxShape.circle]).
  ///
  /// Defaults to [BoxShape.rectangle].
  final BoxShape shape;

  /// Creates a rectangular or rounded-rectangle [BloomSkeleton].
  const BloomSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  /// Creates a circular [BloomSkeleton] with equal width and height [size].
  const BloomSkeleton.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = null,
        shape = BoxShape.circle;

  @override
  State<BloomSkeleton> createState() => _BloomSkeletonState();
}

class _BloomSkeletonState extends State<BloomSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = 0.4 + (_controller.value * 0.4);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: colors.secondary.withValues(alpha: opacity),
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.circle
                ? null
                : (widget.borderRadius ?? BorderRadius.circular(context.bloomRadius.md)),
          ),
        );
      },
    );
  }
}
