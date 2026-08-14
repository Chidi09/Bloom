// lib/src/primitives/navigation_menu.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomNavigationMenuItem {
  final String label;
  final Widget? icon;
  final VoidCallback? onTap;
  final bool isCurrent;

  const BloomNavigationMenuItem({
    required this.label,
    this.icon,
    this.onTap,
    this.isCurrent = false,
  });
}

/// Desktop top navigation destination bar matching shadcn base-nova navigation-menu.
class BloomNavigationMenu extends StatelessWidget {
  final List<BloomNavigationMenuItem> items;
  final Widget? leading;
  final Widget? trailing;

  const BloomNavigationMenu({
    super.key,
    required this.items,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 16),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(context.bloomRadius.md),
                  child: Container(
                    height: 32, // h-8
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: item.isCurrent ? colors.surface0 : Colors.transparent,
                      borderRadius: BorderRadius.circular(context.bloomRadius.md),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.icon != null) ...[
                          IconTheme(
                            data: IconThemeData(
                              color: item.isCurrent ? colors.textPrimary : colors.textSecondary,
                              size: 14,
                            ),
                            child: item.icon!,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          item.label,
                          style: TextStyle(
                            color: item.isCurrent ? colors.textPrimary : colors.textSecondary,
                            fontSize: 13.5,
                            fontWeight: item.isCurrent ? FontWeight.w600 : FontWeight.w500,
                            fontFamily: context.bloomTypography.sans,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
