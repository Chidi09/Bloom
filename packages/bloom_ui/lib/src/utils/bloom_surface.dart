// lib/src/utils/bloom_surface.dart
import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import 'extensions.dart';

/// A Material-free elevated surface built on [PhysicalModel].
///
/// Replaces Material's `Material` widget for providing background fill,
/// elevation shadow rendering, and corner clipping.
///
/// ## Usage
/// ```dart
/// BloomSurface(
///   elevation: 2.0,
///   borderRadius: BorderRadius.circular(8),
///   child: const Padding(
///     padding: EdgeInsets.all(16),
///     child: Text('Elevated Card Content'),
///   ),
/// );
/// ```
class BloomSurface extends StatelessWidget {
  /// The widget below this surface.
  final Widget child;

  /// The surface fill color. Defaults to [BloomColorScheme.surface1] when null.
  final Color? color;

  /// The z-coordinate relative to the parent at which to place this physical surface.
  ///
  /// Defaults to `0.0`.
  final double elevation;

  /// The border radius of rounded corners when clipped.
  final BorderRadius? borderRadius;

  /// The shadow color painted beneath this elevated surface.
  ///
  /// Defaults to [BloomColors.black] at 12% opacity when null.
  final Color? shadowColor;

  /// The clipping strategy applied to child content.
  ///
  /// Defaults to [Clip.antiAlias].
  final Clip clipBehavior;

  /// Creates a [BloomSurface] elevated container.
  const BloomSurface({
    super.key,
    required this.child,
    this.color,
    this.elevation = 0.0,
    this.borderRadius,
    this.shadowColor,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    return PhysicalModel(
      shape: BoxShape.rectangle,
      clipBehavior: clipBehavior,
      borderRadius: borderRadius,
      elevation: elevation,
      color: color ?? context.bloomColors.surface1,
      shadowColor: shadowColor ?? BloomColors.black.withValues(alpha: 0.12),
      child: child,
    );
  }
}
