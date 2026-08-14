// lib/src/primitives/sidebar.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'navigation_menu.dart';

class BloomSidebar extends StatelessWidget {
  final int selectedIndex;
  final List<BloomNavigationItem> items;
  final ValueChanged<int> onDestinationSelected;
  final Widget? header;
  final Widget? footer;
  final bool isExtended;

  const BloomSidebar({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onDestinationSelected,
    this.header,
    this.footer,
    this.isExtended = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface1,
        border: Border(right: BorderSide(color: colors.border)),
      ),
      child: NavigationRail(
        extended: isExtended,
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        backgroundColor: Colors.transparent,
        indicatorColor: colors.primary.withOpacity(0.15),
        leading: header,
        trailing: footer != null ? Expanded(child: Align(alignment: Alignment.bottomCenter, child: footer!)) : null,
        destinations: items.map((item) {
          return NavigationRailDestination(
            icon: item.icon,
            selectedIcon: item.activeIcon ?? item.icon,
            label: Text(
              item.label,
              style: TextStyle(fontFamily: context.bloomTypography.sans),
            ),
          );
        }).toList(),
      ),
    );
  }
}
