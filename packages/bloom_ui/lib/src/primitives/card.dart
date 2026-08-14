// lib/src/primitives/card.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

class BloomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const BloomCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    final card = Container(
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(context.bloomRadius.lg),
        border: Border.all(color: colors.border),
        boxShadow: const [BloomShadows.s1],
      ),
      padding: padding ?? const EdgeInsets.all(24.0),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

class BloomCardHeader extends StatelessWidget {
  final Widget? title;
  final Widget? subtitle;
  final Widget? action;

  const BloomCardHeader({
    super.key,
    this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  DefaultTextStyle(
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: context.bloomTypography.sans,
                    ),
                    child: title!,
                  ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  DefaultTextStyle(
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 14,
                      fontFamily: context.bloomTypography.sans,
                    ),
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class BloomCardTitle extends StatelessWidget {
  final String text;

  const BloomCardTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.bloomColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: context.bloomTypography.sans,
      ),
    );
  }
}

class BloomCardDescription extends StatelessWidget {
  final String text;

  const BloomCardDescription(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.bloomColors.textSecondary,
        fontSize: 14,
        fontFamily: context.bloomTypography.sans,
      ),
    );
  }
}

class BloomCardContent extends StatelessWidget {
  final Widget child;

  const BloomCardContent({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: child,
    );
  }
}

class BloomCardFooter extends StatelessWidget {
  final Widget child;

  const BloomCardFooter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 16.0),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.bloomColors.border)),
      ),
      child: child,
    );
  }
}
