// lib/src/primitives/empty.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

/// Empty state container matching shadcn base-nova dashed border container.
class BloomEmpty extends StatelessWidget {
  final Widget? icon;
  final Widget? title;
  final Widget? description;
  final Widget? action;
  final Widget? child;

  const BloomEmpty({
    super.key,
    this.icon,
    this.title,
    this.description,
    this.action,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: colors.surface0.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(context.bloomRadius.xl),
        border: Border.all(color: colors.border, style: BorderStyle.solid),
      ),
      child: Center(
        child: child ??
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.surface0,
                      borderRadius: BorderRadius.circular(context.bloomRadius.md),
                    ),
                    alignment: Alignment.center,
                    child: IconTheme(
                      data: IconThemeData(color: colors.textSecondary, size: 20),
                      child: icon!,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (title != null) ...[
                  DefaultTextStyle(
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: context.bloomTypography.sans,
                      letterSpacing: -0.1,
                    ),
                    textAlign: TextAlign.center,
                    child: title!,
                  ),
                ],
                if (description != null) ...[
                  const SizedBox(height: 4),
                  DefaultTextStyle(
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      fontFamily: context.bloomTypography.sans,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                    child: description!,
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: 16),
                  action!,
                ],
              ],
            ),
      ),
    );
  }
}

class BloomEmptyTitle extends StatelessWidget {
  final String text;
  const BloomEmptyTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text);
}

class BloomEmptyDescription extends StatelessWidget {
  final String text;
  const BloomEmptyDescription(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text);
}
