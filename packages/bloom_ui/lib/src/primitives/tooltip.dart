// lib/src/primitives/tooltip.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

/// Informative tooltip matching shadcn base-nova inverted contrast style.
class BloomTooltip extends StatelessWidget {
  final String? message;
  final Widget? richMessage;
  final Widget child;
  final Duration waitDuration;

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
