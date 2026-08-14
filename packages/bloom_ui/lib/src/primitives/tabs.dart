// lib/src/primitives/tabs.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

class BloomTabItem {
  final String label;
  final Widget? icon;
  final Widget content;

  const BloomTabItem({
    required this.label,
    this.icon,
    required this.content,
  });
}

class BloomTabs extends StatefulWidget {
  final List<BloomTabItem> tabs;
  final int initialIndex;
  final ValueChanged<int>? onTabChanged;

  const BloomTabs({
    super.key,
    required this.tabs,
    this.initialIndex = 0,
    this.onTabChanged,
  });

  @override
  State<BloomTabs> createState() => _BloomTabsState();
}

class _BloomTabsState extends State<BloomTabs> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _select(int index) {
    setState(() => _currentIndex = index);
    widget.onTabChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tab Header Container
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colors.secondary,
            borderRadius: BorderRadius.circular(context.bloomRadius.md),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.tabs.length, (index) {
              final tab = widget.tabs[index];
              final isSelected = index == _currentIndex;

              return GestureDetector(
                onTap: () => _select(index),
                child: AnimatedContainer(
                  duration: BloomMotion.fast,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? colors.surface1 : Colors.transparent,
                    borderRadius: BorderRadius.circular(context.bloomRadius.sm),
                    boxShadow: isSelected ? [BloomShadows.s1] : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tab.icon != null) ...[
                        tab.icon!,
                        const SizedBox(width: 6),
                      ],
                      Text(
                        tab.label,
                        style: TextStyle(
                          color: isSelected ? colors.textPrimary : colors.textSecondary,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontFamily: context.bloomTypography.sans,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        // Tab Content
        widget.tabs[_currentIndex].content,
      ],
    );
  }
}
