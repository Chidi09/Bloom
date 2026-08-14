// lib/src/primitives/dropdown_menu.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomDropdownMenuItem<T> {
  final T value;
  final String label;
  final Widget? icon;
  final bool isDestructive;

  const BloomDropdownMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.isDestructive = false,
  });
}

class BloomDropdownMenu<T> extends StatelessWidget {
  final Widget trigger;
  final List<BloomDropdownMenuItem<T>> items;
  final ValueChanged<T> onSelected;

  const BloomDropdownMenu({
    super.key,
    required this.trigger,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return PopupMenuButton<T>(
      color: colors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.bloomRadius.md),
        side: BorderSide(color: colors.border),
      ),
      onSelected: onSelected,
      itemBuilder: (context) {
        return items.map((item) {
          return PopupMenuItem<T>(
            value: item.value,
            child: Row(
              children: [
                if (item.icon != null) ...[
                  item.icon!,
                  const SizedBox(width: 8),
                ],
                Text(
                  item.label,
                  style: TextStyle(
                    color: item.isDestructive ? colors.error : colors.textPrimary,
                    fontSize: 14,
                    fontFamily: context.bloomTypography.sans,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: trigger,
    );
  }
}
