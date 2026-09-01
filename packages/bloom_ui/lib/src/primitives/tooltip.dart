// lib/src/primitives/tooltip.dart
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

/// An informative tooltip component with inverted contrast styling.
///
/// Wraps Flutter's [RawTooltip] with Bloom tokens for elevation, surface2
/// background, text coloring, rounded corners, and customizable activation delays.
///
/// Example:
/// ```dart
/// BloomTooltip(
///   message: 'Add item to favorites',
///   child: BloomIcon(BloomIcons.favoriteBorder),
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
    final radius = context.bloomRadius;
    final typography = context.bloomTypography;

    return RawTooltip(
      semanticsTooltip: message,
      hoverDelay: waitDuration,
      tooltipBuilder: (BuildContext context, Animation<double> animation) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        final Widget content = richMessage ??
            Text(
              message!,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: typography.sm,
                fontWeight: FontWeight.w500,
                fontFamily: typography.sans,
              ),
            );

        return FadeTransition(
          opacity: curvedAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surface2,
                borderRadius: BorderRadius.circular(radius.sm),
                border: Border.all(color: colors.border),
                boxShadow: const [BloomShadows.s1],
              ),
              child: content,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

