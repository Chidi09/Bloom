// lib/src/primitives/tooltip.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomTooltip extends StatelessWidget {
  final String message;
  final Widget child;

  const BloomTooltip({
    super.key,
    required this.message,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Tooltip(
      message: message,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.textPrimary,
        borderRadius: BorderRadius.circular(context.bloomRadius.sm),
      ),
      textStyle: TextStyle(
        color: colors.surface1,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        fontFamily: context.bloomTypography.sans,
      ),
      child: child,
    );
  }
}
