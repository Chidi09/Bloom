// lib/src/primitives/breadcrumb.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomBreadcrumbItem {
  final String label;
  final VoidCallback? onTap;
  final bool isCurrent;

  const BloomBreadcrumbItem({
    required this.label,
    this.onTap,
    this.isCurrent = false,
  });
}

/// Breadcrumb navigation path matching shadcn base-nova.
class BloomBreadcrumb extends StatelessWidget {
  final List<BloomBreadcrumbItem>? items;
  final List<Widget>? children;
  final Widget separator;

  const BloomBreadcrumb({
    super.key,
    this.items,
    this.children,
    this.separator = const Icon(Icons.chevron_right, size: 14),
  }) : assert(items != null || children != null, 'Provide items or children');

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    if (children != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children!,
      );
    }

    final itemList = items!;
    final kids = <Widget>[];

    for (int i = 0; i < itemList.length; i++) {
      final item = itemList[i];
      final isLast = i == itemList.length - 1 || item.isCurrent;

      if (isLast) {
        kids.add(
          Text(
            item.label,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: context.bloomTypography.sans,
            ),
          ),
        );
      } else {
        kids.add(
          InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(4),
            child: Text(
              item.label,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                fontFamily: context.bloomTypography.sans,
              ),
            ),
          ),
        );
      }

      if (i < itemList.length - 1) {
        kids.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: IconTheme(
              data: IconThemeData(color: colors.textTertiary, size: 14),
              child: separator,
            ),
          ),
        );
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: kids,
    );
  }
}

class BloomBreadcrumbLink extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const BloomBreadcrumbLink(this.text, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          color: context.bloomColors.textSecondary,
          fontSize: 14,
          fontFamily: context.bloomTypography.sans,
        ),
      ),
    );
  }
}

class BloomBreadcrumbPage extends StatelessWidget {
  final String text;
  const BloomBreadcrumbPage(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.bloomColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontFamily: context.bloomTypography.sans,
      ),
    );
  }
}

class BloomBreadcrumbEllipsis extends StatelessWidget {
  const BloomBreadcrumbEllipsis({super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.more_horiz,
      size: 14,
      color: context.bloomColors.textTertiary,
    );
  }
}
