// lib/src/primitives/input_group.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomInputGroupAddon extends StatelessWidget {
  final Widget child;

  const BloomInputGroupAddon({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final theme = context.bloomTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(),
      alignment: Alignment.center,
      child: DefaultTextStyle(
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 14,
          fontFamily: theme.typography.sans,
        ),
        child: child,
      ),
    );
  }
}

class BloomInputGroup extends StatelessWidget {
  final Widget? leftAddon;
  final Widget input;
  final Widget? rightAddon;

  const BloomInputGroup({
    super.key,
    this.leftAddon,
    required this.input,
    this.rightAddon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final theme = context.bloomTheme;
    final radius = theme.radius.md;

    return IntrinsicHeight(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Row(
            children: [
              if (leftAddon != null)
                Container(
                  decoration: BoxDecoration(
                    color: colors.surface2,
                    border: Border(
                      right: BorderSide(color: colors.border),
                    ),
                  ),
                  child: leftAddon!,
                ),
              Expanded(child: input),
              if (rightAddon != null)
                Container(
                  decoration: BoxDecoration(
                    color: colors.surface2,
                    border: Border(
                      left: BorderSide(color: colors.border),
                    ),
                  ),
                  child: rightAddon!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
