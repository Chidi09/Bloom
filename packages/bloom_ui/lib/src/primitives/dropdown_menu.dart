// lib/src/primitives/dropdown_menu.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomDropdownMenuItem {
  final String label;
  final Widget? icon;
  final Widget? shortcut;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool disabled;

  const BloomDropdownMenuItem({
    required this.label,
    this.icon,
    this.shortcut,
    this.onTap,
    this.isDestructive = false,
    this.disabled = false,
  });
}

/// Contextual dropdown menu popup matching shadcn base-nova.
class BloomDropdownMenu extends StatelessWidget {
  final Widget trigger;
  final List<BloomDropdownMenuItem> items;
  final double width;

  const BloomDropdownMenu({
    super.key,
    required this.trigger,
    required this.items,
    this.width = 200,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return PopupMenuButton<int>(
      tooltip: '',
      offset: const Offset(0, 6),
      color: colors.surface1,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.bloomRadius.lg),
        side: BorderSide(color: colors.border),
      ),
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: width, maxWidth: width),
      itemBuilder: (ctx) {
        return List.generate(items.length, (index) {
          final item = items[index];
          final textCol = item.isDestructive
              ? colors.destructive
              : item.disabled
                  ? colors.textTertiary
                  : colors.textPrimary;

          return PopupMenuItem<int>(
            value: index,
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            enabled: !item.disabled,
            child: Row(
              children: [
                if (item.icon != null) ...[
                  IconTheme(
                    data: IconThemeData(color: textCol, size: 16),
                    child: item.icon!,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: textCol,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      fontFamily: context.bloomTypography.sans,
                    ),
                  ),
                ),
                if (item.shortcut != null) item.shortcut!,
              ],
            ),
          );
        });
      },
      onSelected: (index) {
        items[index].onTap?.call();
      },
      child: trigger,
    );
  }
}

class BloomDropdownMenuSeparator extends StatelessWidget {
  const BloomDropdownMenuSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: context.bloomColors.border,
    );
  }
}
