// lib/src/primitives/bubble.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

enum BloomBubbleVariant {
  defaultVariant,
  secondary,
  muted,
  outline,
  ghost,
  tinted,
  destructive,
}

enum BloomBubbleAlign {
  start,
  end,
}

class BloomBubble extends StatelessWidget {
  final BloomBubbleVariant variant;
  final BloomBubbleAlign align;
  final Widget content;
  final Widget? header;
  final Widget? footer;
  final Widget? reaction;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry? borderRadius;

  const BloomBubble({
    super.key,
    required this.content,
    this.variant = BloomBubbleVariant.defaultVariant,
    this.align = BloomBubbleAlign.start,
    this.header,
    this.footer,
    this.reaction,
    this.maxWidth = 0.8,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.bloomTheme;
    final isEnd = align == BloomBubbleAlign.end;

    return Align(
      alignment: isEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * maxWidth),
        child: Column(
          crossAxisAlignment: isEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (header != null)
              Padding(
                padding: EdgeInsets.only(
                  bottom: theme.spacing.s1,
                  left: isEnd ? 0 : 4,
                  right: isEnd ? 4 : 0,
                ),
                child: header,
              ),
            BloomBubbleContent(
              variant: variant,
              padding: padding,
              borderRadius: borderRadius,
              child: content,
            ),
            if (footer != null)
              Padding(
                padding: EdgeInsets.only(top: theme.spacing.s1),
                child: footer,
              ),
            if (reaction != null)
              Padding(
                padding: EdgeInsets.only(top: theme.spacing.s1),
                child: reaction,
              ),
          ],
        ),
      ),
    );
  }
}

class BloomBubbleContent extends StatelessWidget {
  final BloomBubbleVariant variant;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry? borderRadius;

  const BloomBubbleContent({
    super.key,
    required this.child,
    this.variant = BloomBubbleVariant.defaultVariant,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.bloomTheme;
    final colors = _resolveColors(context, variant);

    return AnimatedContainer(
      duration: theme.spacing.s1 > 0 ? const Duration(milliseconds: 100) : Duration.zero,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.background,
        border: colors.border != Colors.transparent ? Border.all(color: colors.border) : null,
        borderRadius: borderRadius ?? BorderRadius.circular(theme.radius.lg),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: colors.foreground,
          fontSize: 14,
          fontFamily: theme.typography.sans,
        ),
        child: child,
      ),
    );
  }

  static _BubbleColors _resolveColors(BuildContext context, BloomBubbleVariant variant) {
    final c = context.bloomColors;
    switch (variant) {
      case BloomBubbleVariant.defaultVariant:
        return _BubbleColors(background: c.primary, foreground: c.primaryForeground, border: Colors.transparent);
      case BloomBubbleVariant.secondary:
        return _BubbleColors(background: c.secondary, foreground: c.secondaryForeground, border: Colors.transparent);
      case BloomBubbleVariant.muted:
        return _BubbleColors(background: c.surface0, foreground: c.textPrimary, border: Colors.transparent);
      case BloomBubbleVariant.outline:
        return _BubbleColors(background: Colors.transparent, foreground: c.textPrimary, border: c.border);
      case BloomBubbleVariant.ghost:
        return _BubbleColors(background: Colors.transparent, foreground: c.textPrimary, border: Colors.transparent);
      case BloomBubbleVariant.tinted:
        return _BubbleColors(background: c.surface2, foreground: c.textPrimary, border: c.border);
      case BloomBubbleVariant.destructive:
        return _BubbleColors(background: c.destructive, foreground: c.destructiveForeground, border: Colors.transparent);
    }
  }
}

class _BubbleColors {
  final Color background;
  final Color foreground;
  final Color border;
  const _BubbleColors({required this.background, required this.foreground, required this.border});
}

class BloomBubbleReactions extends StatelessWidget {
  final List<Widget> children;
  final bool showOnTop;

  const BloomBubbleReactions({
    super.key,
    required this.children,
    this.showOnTop = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      direction: showOnTop ? Axis.horizontal : Axis.horizontal,
      children: children,
    );
  }
}
