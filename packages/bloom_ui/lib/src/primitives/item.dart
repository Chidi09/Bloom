// lib/src/primitives/item.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

enum BloomItemVariant {
  defaultVariant,
  outline,
  muted,
}

enum BloomItemSize {
  defaultSize,
  sm,
  xs,
}

class BloomItem extends StatelessWidget {
  final Widget? media;
  final Widget? title;
  final Widget? description;
  final List<Widget> actions;
  final BloomItemVariant variant;
  final BloomItemSize size;
  final VoidCallback? onTap;

  const BloomItem({
    super.key,
    this.media,
    this.title,
    this.description,
    this.actions = const [],
    this.variant = BloomItemVariant.defaultVariant,
    this.size = BloomItemSize.defaultSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final theme = context.bloomTheme;
    final dims = _resolveDimensions(size);

    Color bg;
    Color border;
    switch (variant) {
      case BloomItemVariant.defaultVariant:
        bg = colors.surface1;
        border = colors.border;
      case BloomItemVariant.outline:
        bg = Colors.transparent;
        border = colors.border;
      case BloomItemVariant.muted:
        bg = colors.surface2;
        border = Colors.transparent;
    }

    final item = Container(
      padding: dims.padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: border != Colors.transparent ? Border.all(color: border) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (media != null) ...[
            Padding(
              padding: EdgeInsets.only(right: dims.gap),
              child: SizedBox(width: dims.mediaSize, height: dims.mediaSize, child: media!),
            ),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  DefaultTextStyle(
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: dims.titleSize,
                      fontWeight: FontWeight.w600,
                      fontFamily: theme.typography.sans,
                    ),
                    child: title!,
                  ),
                if (description != null)
                  Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: DefaultTextStyle(
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: dims.descSize,
                        fontFamily: theme.typography.sans,
                      ),
                      child: description!,
                    ),
                  ),
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            SizedBox(width: dims.gap),
            Row(mainAxisSize: MainAxisSize.min, children: actions),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return Semantics(
        button: true,
        child: GestureDetector(onTap: onTap, child: item),
      );
    }
    return item;
  }

  static _ItemDimensions _resolveDimensions(BloomItemSize size) {
    switch (size) {
      case BloomItemSize.defaultSize:
        return const _ItemDimensions(
          padding: EdgeInsets.all(12),
          gap: 12,
          mediaSize: 40,
          titleSize: 14,
          descSize: 13,
        );
      case BloomItemSize.sm:
        return const _ItemDimensions(
          padding: EdgeInsets.all(10),
          gap: 10,
          mediaSize: 32,
          titleSize: 13,
          descSize: 12,
        );
      case BloomItemSize.xs:
        return const _ItemDimensions(
          padding: EdgeInsets.all(8),
          gap: 8,
          mediaSize: 24,
          titleSize: 12,
          descSize: 11,
        );
    }
  }
}

class _ItemDimensions {
  final EdgeInsetsGeometry padding;
  final double gap;
  final double mediaSize;
  final double titleSize;
  final double descSize;
  const _ItemDimensions({
    required this.padding,
    required this.gap,
    required this.mediaSize,
    required this.titleSize,
    required this.descSize,
  });
}

class BloomItemTitle extends StatelessWidget {
  final String text;

  const BloomItemTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.bloomColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        fontFamily: context.bloomTypography.sans,
      ),
    );
  }
}

class BloomItemDescription extends StatelessWidget {
  final String text;

  const BloomItemDescription(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.bloomColors.textSecondary,
        fontSize: 13,
        fontFamily: context.bloomTypography.sans,
      ),
    );
  }
}

class BloomItemMedia extends StatelessWidget {
  final Widget child;
  final double size;

  const BloomItemMedia({
    super.key,
    required this.child,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: child);
  }
}

class BloomItemActions extends StatelessWidget {
  final List<Widget> children;

  const BloomItemActions({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

class BloomItemGroup extends StatelessWidget {
  final List<BloomItem> items;
  final double spacing;
  final BloomItemVariant variant;
  final BloomItemSize size;

  const BloomItemGroup({
    super.key,
    required this.items,
    this.spacing = 4,
    this.variant = BloomItemVariant.defaultVariant,
    this.size = BloomItemSize.defaultSize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(items.length, (i) {
        return Padding(
          padding: EdgeInsets.only(top: i > 0 ? spacing : 0),
          child: BloomItem(
            media: items[i].media,
            title: items[i].title,
            description: items[i].description,
            actions: items[i].actions,
            variant: items[i].variant,
            size: items[i].size,
            onTap: items[i].onTap,
          ),
        );
      }),
    );
  }
}
