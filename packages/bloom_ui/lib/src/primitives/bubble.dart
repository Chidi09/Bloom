// lib/src/primitives/bubble.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

/// Visual styling variants for chat bubbles.
enum BloomBubbleVariant {
  /// Solid primary styling using theme primary background and foreground colors.
  defaultVariant,

  /// Secondary styling using theme secondary background and foreground colors.
  secondary,

  /// Muted background styling using `surface0` and primary text colors.
  muted,

  /// Transparent background with border outline.
  outline,

  /// Transparent background with no border.
  ghost,

  /// Tinted surface styling using `surface2` background and border.
  tinted,

  /// Destructive/error styling using destructive background and foreground colors.
  destructive,
}

/// Alignment positions for [BloomBubble].
enum BloomBubbleAlign {
  /// Aligns bubble to the start (left in LTR).
  start,

  /// Aligns bubble to the end (right in LTR).
  end,
}

/// A flexible chat bubble container supporting header, footer, reactions, and variants.
///
/// Example:
/// ```dart
/// BloomBubble(
///   variant: BloomBubbleVariant.defaultVariant,
///   align: BloomBubbleAlign.end,
///   content: Text('Sounds great, let me review!'),
///   footer: Text('10:45 AM'),
/// )
/// ```
class BloomBubble extends StatelessWidget {
  /// Visual variant styling for the bubble container. Defaults to [BloomBubbleVariant.defaultVariant].
  final BloomBubbleVariant variant;

  /// Alignment of the bubble. Defaults to [BloomBubbleAlign.start].
  final BloomBubbleAlign align;

  /// The primary content widget placed inside the bubble.
  final Widget content;

  /// Optional header widget rendered above the bubble.
  final Widget? header;

  /// Optional footer widget rendered below the bubble.
  final Widget? footer;

  /// Optional reaction widget rendered below or alongside the bubble.
  final Widget? reaction;

  /// Maximum width fraction of screen width (0.0 to 1.0). Defaults to 0.8.
  final double maxWidth;

  /// Internal padding for the bubble content. Defaults to horizontal 14, vertical 10.
  final EdgeInsetsGeometry padding;

  /// Custom border radius override for the bubble container.
  final BorderRadiusGeometry? borderRadius;

  /// Creates a [BloomBubble].
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

/// The styled container wrapping the child content within a [BloomBubble].
///
/// Example:
/// ```dart
/// BloomBubbleContent(
///   variant: BloomBubbleVariant.secondary,
///   child: Text('Bubble content here'),
/// )
/// ```
class BloomBubbleContent extends StatelessWidget {
  /// Visual variant styling. Defaults to [BloomBubbleVariant.defaultVariant].
  final BloomBubbleVariant variant;

  /// The child widget to render inside the styled container.
  final Widget child;

  /// Internal padding for the bubble content. Defaults to horizontal 14, vertical 10.
  final EdgeInsetsGeometry padding;

  /// Custom border radius override.
  final BorderRadiusGeometry? borderRadius;

  /// Creates a [BloomBubbleContent].
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

/// A wrap layout container for displaying emoji or action reactions on a bubble.
///
/// Example:
/// ```dart
/// BloomBubbleReactions(
///   children: [
///     BloomBadge(child: Text('👍 3')),
///     BloomBadge(child: Text('❤️ 1')),
///   ],
/// )
/// ```
class BloomBubbleReactions extends StatelessWidget {
  /// The list of reaction widgets to display in a wrapped row.
  final List<Widget> children;

  /// Whether to display reactions aligned horizontally across top/bottom. Defaults to false.
  final bool showOnTop;

  /// Creates a [BloomBubbleReactions].
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
