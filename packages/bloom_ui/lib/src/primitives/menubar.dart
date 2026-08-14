// lib/src/primitives/menubar.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'dropdown_menu.dart';

class BloomMenubarMenu {
  final String title;
  final List<BloomDropdownMenuItem> items;
  const BloomMenubarMenu({required this.title, required this.items});
}

/// Desktop top application menubar matching shadcn base-nova.
class BloomMenubar extends StatelessWidget {
  final List<BloomMenubarMenu> menus;

  const BloomMenubar({super.key, required this.menus});

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Container(
      height: 36, // h-9
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(context.bloomRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: menus.map((menu) {
          return BloomDropdownMenu(
            trigger: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              alignment: Alignment.center,
              child: Text(
                menu.title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  fontFamily: context.bloomTypography.sans,
                ),
              ),
            ),
            items: menu.items,
          );
        }).toList(),
      ),
    );
  }
}
