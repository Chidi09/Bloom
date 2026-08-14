// lib/src/primitives/app_shell.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'sidebar.dart';

class BloomNavigationItem {
  final Widget icon;
  final Widget label;
  final Widget? trailing;

  const BloomNavigationItem({
    required this.icon,
    required this.label,
    this.trailing,
  });
}

class BloomAppShell extends StatelessWidget {
  final Widget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  const BloomAppShell({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bloomColors.surface0,
      appBar: appBar != null ? PreferredSize(preferredSize: const Size.fromHeight(56), child: appBar!) : null,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

class BloomDashboardShell extends StatelessWidget {
  final int selectedIndex;
  final List<BloomNavigationItem> navigationItems;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final Widget? sidebarHeader;
  final Widget? sidebarFooter;
  final Widget? topBar;

  const BloomDashboardShell({
    super.key,
    required this.selectedIndex,
    required this.navigationItems,
    required this.onDestinationSelected,
    required this.body,
    this.sidebarHeader,
    this.sidebarFooter,
    this.topBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bloomColors.surface0,
      body: Row(
        children: [
          BloomSidebar(
            header: sidebarHeader,
            footer: sidebarFooter,
            content: Column(
              children: List.generate(navigationItems.length, (i) {
                final item = navigationItems[i];
                return BloomSidebarMenuButton(
                  icon: item.icon,
                  label: item.label,
                  trailing: item.trailing,
                  isCurrent: selectedIndex == i,
                  onTap: () => onDestinationSelected(i),
                );
              }),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                if (topBar != null) topBar!,
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
