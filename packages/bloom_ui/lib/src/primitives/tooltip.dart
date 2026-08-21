// lib/src/primitives/tooltip.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

/// An informative tooltip component with inverted contrast styling.
///
/// Wraps Flutter's [Tooltip] with Bloom tokens for elevation, primary foreground
/// text coloring, rounded corners, and customizable activation delays.
///
/// Example:
/// ```dart
/// BloomTooltip(
///   message: 'Add item to favorites',
///   child: IconButton(
///     icon: const Icon(Icons.favorite_border),
///     onPressed: () {},
///   ),
/// );
/// ```
class BloomTooltip extends StatelessWidget {
  /// Plain text message displayed inside the tooltip bubble.
  final String? message;

  /// Rich custom widget content displayed inside the tooltip bubble.
  final Widget? richMessage;

  /// The widget that triggers the tooltip on hover or long-press.
  final Widget child;

  /// The duration to wait before displaying the tooltip on pointer hover.
  /// Defaults to `300` milliseconds.
  final Duration waitDuration;

  /// Creates a [BloomTooltip].
  ///
  /// Either [message] or [richMessage] must be provided.
  ///
  /// * [message]: Plain string tooltip text.
  /// * [richMessage]: Custom widget tooltip content.
  /// * [child]: The target widget wrapped by the tooltip trigger.
  /// * [waitDuration]: Hover delay duration before opening (defaults to 300ms).
  const BloomTooltip({
    super.key,
    this.message,
    this.richMessage,
    required this.child,
    this.waitDuration = const Duration(milliseconds: 300),
  }) : assert(message != null || richMessage != null, 'Provide message or richMessage');

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    if (richMessage != null) {
      return Tooltip(
        richMessage: WidgetSpan(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: richMessage!,
          ),
        ),
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [BloomShadows.s1],
        ),
        waitDuration: waitDuration,
        child: child,
      );
    }

    return Tooltip(
      message: message!,
      textStyle: TextStyle(
        color: colors.primaryForeground,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        fontFamily: context.bloomTypography.sans,
      ),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BloomShadows.s1],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      waitDuration: waitDuration,
      child: child,
    );
  }
}

