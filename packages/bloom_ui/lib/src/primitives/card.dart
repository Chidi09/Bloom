// lib/src/primitives/card.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

enum BloomCardSize { defaultSize, sm }

/// Composable container card matching shadcn/ui base-nova structure and styles.
class BloomCard extends StatelessWidget {
  final Widget? header;
  final Widget? content;
  final Widget? footer;
  final Widget? child;
  final BloomCardSize size;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  const BloomCard({
    super.key,
    this.header,
    this.content,
    this.footer,
    this.child,
    this.size = BloomCardSize.defaultSize,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final padding = size == BloomCardSize.sm ? 12.0 : 16.0;
    final radius = context.bloomRadius.xl;

    final cardContent = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.surface1,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? colors.border),
        boxShadow: const [BloomShadows.s1],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) header!,
            if (content != null) content!,
            if (child != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding),
                child: child!,
              ),
            if (footer != null) footer!,
          ],
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}

/// Header slot for BloomCard with title, description, and optional right-aligned action.
class BloomCardHeader extends StatelessWidget {
  final Widget? title;
  final Widget? description;
  final Widget? action;
  final Widget? child;
  final BloomCardSize size;

  const BloomCardHeader({
    super.key,
    this.title,
    this.description,
    this.action,
    this.child,
    this.size = BloomCardSize.defaultSize,
  });

  @override
  Widget build(BuildContext context) {
    final padding = size == BloomCardSize.sm ? 12.0 : 16.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, padding, padding, padding / 2),
      child: child ??
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null) title!,
                    if (description != null) ...[
                      const SizedBox(height: 4),
                      description!,
                    ],
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 12),
                action!,
              ],
            ],
          ),
    );
  }
}

/// Title for BloomCard
class BloomCardTitle extends StatelessWidget {
  final String text;
  final BloomCardSize size;

  const BloomCardTitle(this.text, {super.key, this.size = BloomCardSize.defaultSize});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: size == BloomCardSize.sm ? 14 : 16,
        fontWeight: FontWeight.w600,
        fontFamily: context.bloomTypography.sans,
        color: context.bloomColors.textPrimary,
        letterSpacing: -0.2,
      ),
    );
  }
}

/// Secondary subtitle description for BloomCard
class BloomCardDescription extends StatelessWidget {
  final String text;

  const BloomCardDescription(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        fontFamily: context.bloomTypography.sans,
        color: context.bloomColors.textSecondary,
        height: 1.4,
      ),
    );
  }
}

/// Action slot wrapper
class BloomCardAction extends StatelessWidget {
  final Widget child;
  const BloomCardAction({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

/// Content slot for BloomCard
class BloomCardContent extends StatelessWidget {
  final Widget child;
  final BloomCardSize size;

  const BloomCardContent({super.key, required this.child, this.size = BloomCardSize.defaultSize});

  @override
  Widget build(BuildContext context) {
    final padding = size == BloomCardSize.sm ? 12.0 : 16.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, padding / 2, padding, padding),
      child: child,
    );
  }
}

/// Styled footer slot for BloomCard with subtle tinted background and top border.
class BloomCardFooter extends StatelessWidget {
  final Widget child;
  final BloomCardSize size;
  final MainAxisAlignment alignment;

  const BloomCardFooter({
    super.key,
    required this.child,
    this.size = BloomCardSize.defaultSize,
    this.alignment = MainAxisAlignment.end,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final padding = size == BloomCardSize.sm ? 12.0 : 16.0;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface0.withValues(alpha: 0.5),
        border: Border(top: BorderSide(color: colors.border)),
      ),
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding * 0.8),
      child: Row(
        mainAxisAlignment: alignment,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [child],
      ),
    );
  }
}
