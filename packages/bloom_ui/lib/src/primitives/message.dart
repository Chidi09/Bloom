// lib/src/primitives/message.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

/// Visual styling variants for [BloomMessage] and [BloomMessageGroup].
enum BloomMessageVariant {
  /// Primary background styling using theme primary colors.
  defaultVariant,

  /// Secondary background styling using theme secondary colors.
  secondary,

  /// Muted background styling using `surface0` colors.
  muted,

  /// Outlined background styling with transparent fill and a border.
  outline,

  /// Ghost styling with transparent background and no border.
  ghost,
}

/// Alignment options for [BloomMessage] and [BloomMessageGroup].
enum BloomMessageAlign {
  /// Aligns message to the start (left in LTR), typically for incoming messages.
  start,

  /// Aligns message to the end (right in LTR), typically for outgoing/user messages.
  end,
}

/// A chat or conversation message bubble with optional avatar, sender name, timestamp, and footer.
///
/// Example:
/// ```dart
/// BloomMessage(
///   name: 'Alex',
///   timestamp: '10:42 AM',
///   content: Text('Hello, how can I help you today?'),
///   variant: BloomMessageVariant.muted,
///   align: BloomMessageAlign.start,
/// )
/// ```
class BloomMessage extends StatelessWidget {
  /// Optional avatar widget placed beside the message bubble.
  final Widget? avatar;

  /// Optional sender name displayed above the message bubble.
  final String? name;

  /// Optional timestamp string displayed next to the sender name.
  final String? timestamp;

  /// The main message body widget.
  final Widget content;

  /// Optional widget displayed below the bubble (e.g. status or action buttons).
  final Widget? footer;

  /// Visual styling variant for the bubble. Defaults to [BloomMessageVariant.defaultVariant].
  final BloomMessageVariant variant;

  /// Alignment of the message bubble within the layout. Defaults to [BloomMessageAlign.start].
  final BloomMessageAlign align;

  /// Creates a [BloomMessage].
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

/// A container for grouping multiple consecutive messages from the same sender.
///
/// Example:
/// ```dart
/// BloomMessageGroup(
///   name: 'Assistant',
///   timestamp: 'Just now',
///   messages: [
///     BloomMessage(content: Text('Here is the first piece of info.')),
///     BloomMessage(content: Text('And here is a follow-up.')),
///   ],
/// )
/// ```
class BloomMessageGroup extends StatelessWidget {
  /// Optional avatar widget placed beside the message group.
  final Widget? avatar;

  /// Optional sender name displayed above the group.
  final String? name;

  /// The list of message widgets in this group.
  final List<Widget> messages;

  /// Optional timestamp string displayed next to the sender name.
  final String? timestamp;

  /// Visual styling variant for child messages. Defaults to [BloomMessageVariant.defaultVariant].
  final BloomMessageVariant variant;

  /// Alignment of the message group within the layout. Defaults to [BloomMessageAlign.start].
  final BloomMessageAlign align;

  /// Creates a [BloomMessageGroup].
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
