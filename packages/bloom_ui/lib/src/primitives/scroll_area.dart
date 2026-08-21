// lib/src/primitives/scroll_area.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

/// A scrollable area container with customized minimalist scrollbars matching the Bloom design system.
///
/// Wraps its [child] in a [SingleChildScrollView] paired with a visible, rounded [Scrollbar]
/// styled with [BloomColorScheme.border] color and pill-shaped thumb radius.
///
/// ```dart
/// BloomScrollArea(
///   scrollDirection: Axis.vertical,
///   padding: EdgeInsets.all(16),
///   child: Column(
///     children: List.generate(50, (i) => Text('Item $i')),
///   ),
/// );
/// ```
class BloomScrollArea extends StatelessWidget {
  /// The widget that will be scrolled inside the viewport.
  final Widget child;

  /// An optional [ScrollController] to control or observe the scroll position.
  final ScrollController? controller;

  /// The axis along which the scroll area expands and scrolls.
  ///
  /// Defaults to [Axis.vertical].
  final Axis scrollDirection;

  /// Padding applied to the inside of the scrollable content.
  final EdgeInsetsGeometry? padding;

  /// Creates a [BloomScrollArea].
  ///
  /// The [child] parameter is required.
  const BloomScrollArea({
    super.key,
    required this.child,
    this.controller,
    this.scrollDirection = Axis.vertical,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Theme(
      data: Theme.of(context).copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(colors.border),
          radius: const Radius.circular(999),
          thickness: WidgetStateProperty.all(6),
        ),
      ),
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: controller,
          scrollDirection: scrollDirection,
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
