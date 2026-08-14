// lib/src/primitives/item.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

/// Versatile list item component matching shadcn/ui base-nova.
class BloomItem extends StatelessWidget {
  final Widget? media;
  final Widget? title;
  final Widget? description;
  final Widget? actions;
  final Widget? child;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool disabled;

  const BloomItem({
    super.key,
    this.media,
    this.title,
    this.description,
    this.actions,
    this.child,
    this.onTap,
    this.isSelected = false,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? colors.surface0 : Colors.transparent,
        borderRadius: BorderRadius.circular(context.bloomRadius.md),
      ),
      child: child ??
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (media != null) ...[
                media!,
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      DefaultTextStyle(
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          fontFamily: context.bloomTypography.sans,
                        ),
                        child: title!,
                      ),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      DefaultTextStyle(
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          fontFamily: context.bloomTypography.sans,
                        ),
                        child: description!,
                      ),
                    ],
                  ],
                ),
              ),
              if (actions != null) ...[
                const SizedBox(width: 8),
                actions!,
              ],
            ],
          ),
    );

    if (onTap != null && !disabled) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.bloomRadius.md),
        child: tile,
      );
    }

    return tile;
  }
}

class BloomItemMedia extends StatelessWidget {
  final Widget child;
  const BloomItemMedia({super.key, required this.child});
  @override
  Widget build(BuildContext context) => child;
}

class BloomItemTitle extends StatelessWidget {
  final String text;
  const BloomItemTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text);
}

class BloomItemDescription extends StatelessWidget {
  final String text;
  const BloomItemDescription(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text);
}

class BloomItemActions extends StatelessWidget {
  final Widget child;
  const BloomItemActions({super.key, required this.child});
  @override
  Widget build(BuildContext context) => child;
}

class BloomItemGroup extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const BloomItemGroup({super.key, required this.children, this.spacing = 2});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children
          .map((c) => Padding(padding: EdgeInsets.only(bottom: spacing), child: c))
          .toList(),
    );
  }
}
