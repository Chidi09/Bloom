// lib/src/primitives/breadcrumb.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomBreadcrumbItem {
  final String label;
  final VoidCallback? onTap;

  const BloomBreadcrumbItem({
    required this.label,
    this.onTap,
  });
}

class BloomBreadcrumb extends StatelessWidget {
  final List<BloomBreadcrumbItem> items;
  final Widget? separator;

  const BloomBreadcrumb({
    super.key,
    required this.items,
    this.separator,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(items.length * 2 - 1, (index) {
        if (index.isOdd) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: separator ?? Icon(Icons.chevron_right, size: 16, color: colors.textTertiary),
          );
        }

        final itemIndex = index ~/ 2;
        final item = items[itemIndex];
        final isLast = itemIndex == items.length - 1;

        final text = Text(
          item.label,
          style: TextStyle(
            color: isLast ? colors.textPrimary : colors.textSecondary,
            fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
            fontFamily: context.bloomTypography.sans,
          ),
        );

        if (item.onTap != null && !isLast) {
          return InkWell(onTap: item.onTap, child: text);
        }
        return text;
      }),
    );
  }
}
