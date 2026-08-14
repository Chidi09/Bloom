// lib/src/primitives/navigation_menu.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomNavigationItem {
  final String label;
  final Widget icon;
  final Widget? activeIcon;

  const BloomNavigationItem({
    required this.label,
    required this.icon,
    this.activeIcon,
  });
}

class BloomNavigationMenu extends StatelessWidget {
  final int selectedIndex;
  final List<BloomNavigationItem> items;
  final ValueChanged<int> onDestinationSelected;

  const BloomNavigationMenu({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      backgroundColor: colors.surface1,
      indicatorColor: colors.primary.withValues(alpha: 0.15),
      destinations: items.map((item) {
        return NavigationDestination(
          icon: item.icon,
          selectedIcon: item.activeIcon ?? item.icon,
          label: item.label,
        );
      }).toList(),
    );
  }
}
