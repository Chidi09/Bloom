// lib/src/primitives/message.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

enum BloomMessageVariant {
  defaultVariant,
  secondary,
  muted,
  outline,
  ghost,
}

enum BloomMessageAlign {
  start,
  end,
}

class BloomMessage extends StatelessWidget {
  final Widget? avatar;
  final String? name;
  final String? timestamp;
  final Widget content;
  final Widget? footer;
  final BloomMessageVariant variant;
  final BloomMessageAlign align;

  const BloomMessage({
    super.key,
    this.avatar,
    this.name,
    this.timestamp,
    required this.content,
    this.footer,
    this.variant = BloomMessageVariant.defaultVariant,
    this.align = BloomMessageAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final theme = context.bloomTheme;
    final isEnd = align == BloomMessageAlign.end;

    final resolved = _resolveColors(context, variant);

    final bubble = Column(
      crossAxisAlignment: isEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (name != null || timestamp != null)
          Padding(
            padding: EdgeInsets.only(
              bottom: theme.spacing.s1,
              left: isEnd ? 0 : 4,
              right: isEnd ? 4 : 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (name != null)
                  Text(
                    name!,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: theme.typography.sans,
                    ),
                  ),
                if (name != null && timestamp != null) const SizedBox(width: 8),
                if (timestamp != null)
                  Text(
                    timestamp!,
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 11,
                      fontFamily: theme.typography.sans,
                    ),
                  ),
              ],
            ),
          ),
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: resolved.background,
            border: resolved.border != Colors.transparent ? Border.all(color: resolved.border) : null,
            borderRadius: BorderRadius.circular(theme.radius.lg),
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              color: resolved.foreground,
              fontSize: 14,
              fontFamily: theme.typography.sans,
            ),
            child: content,
          ),
        ),
        if (footer != null)
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.s1),
            child: footer!,
          ),
      ],
    );

    if (avatar == null) return bubble;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: isEnd ? TextDirection.rtl : TextDirection.ltr,
      children: [
        Padding(
          padding: EdgeInsets.only(
            right: isEnd ? 0 : theme.spacing.s2,
            left: isEnd ? theme.spacing.s2 : 0,
          ),
          child: SizedBox(width: 32, height: 32, child: avatar),
        ),
        Flexible(child: bubble),
      ],
    );
  }

  static _MessageColors _resolveColors(BuildContext context, BloomMessageVariant variant) {
    final c = context.bloomColors;
    switch (variant) {
      case BloomMessageVariant.defaultVariant:
        return _MessageColors(background: c.primary, foreground: c.primaryForeground, border: Colors.transparent);
      case BloomMessageVariant.secondary:
        return _MessageColors(background: c.secondary, foreground: c.secondaryForeground, border: Colors.transparent);
      case BloomMessageVariant.muted:
        return _MessageColors(background: c.surface0, foreground: c.textPrimary, border: Colors.transparent);
      case BloomMessageVariant.outline:
        return _MessageColors(background: Colors.transparent, foreground: c.textPrimary, border: c.border);
      case BloomMessageVariant.ghost:
        return _MessageColors(background: Colors.transparent, foreground: c.textPrimary, border: Colors.transparent);
    }
  }
}

class _MessageColors {
  final Color background;
  final Color foreground;
  final Color border;
  const _MessageColors({required this.background, required this.foreground, required this.border});
}

class BloomMessageGroup extends StatelessWidget {
  final Widget? avatar;
  final String? name;
  final List<Widget> messages;
  final String? timestamp;
  final BloomMessageVariant variant;
  final BloomMessageAlign align;

  const BloomMessageGroup({
    super.key,
    this.avatar,
    this.name,
    required this.messages,
    this.timestamp,
    this.variant = BloomMessageVariant.defaultVariant,
    this.align = BloomMessageAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.bloomTheme;
    final isEnd = align == BloomMessageAlign.end;

    final content = Column(
      crossAxisAlignment: isEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (name != null)
          Padding(
            padding: EdgeInsets.only(
              bottom: theme.spacing.s1,
              left: isEnd ? 0 : 4,
              right: isEnd ? 4 : 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name!,
                  style: TextStyle(
                    color: context.bloomColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: theme.typography.sans,
                  ),
                ),
                if (timestamp != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    timestamp!,
                    style: TextStyle(
                      color: context.bloomColors.textTertiary,
                      fontSize: 11,
                      fontFamily: theme.typography.sans,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ...messages.asMap().entries.map((e) {
          return Padding(
            padding: e.key > 0 ? EdgeInsets.only(top: theme.spacing.s1) : EdgeInsets.zero,
            child: e.value,
          );
        }),
      ],
    );

    if (avatar == null) return content;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      textDirection: isEnd ? TextDirection.rtl : TextDirection.ltr,
      children: [
        Padding(
          padding: EdgeInsets.only(
            right: isEnd ? 0 : theme.spacing.s2,
            left: isEnd ? theme.spacing.s2 : 0,
          ),
          child: SizedBox(width: 32, height: 32, child: avatar),
        ),
        Flexible(child: content),
      ],
    );
  }
}
