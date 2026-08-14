// lib/src/primitives/filter_bar.dart
import 'package:flutter/material.dart';
import 'badge.dart';

class BloomFilterBar<T> extends StatelessWidget {
  final List<T> options;
  final T selectedOption;
  final String Function(T option) labelBuilder;
  final ValueChanged<T> onSelected;

  const BloomFilterBar({
    super.key,
    required this.options,
    required this.selectedOption,
    required this.labelBuilder,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((option) {
          final isSelected = option == selectedOption;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: BloomChip(
              label: Text(labelBuilder(option)),
              variant: isSelected ? BloomBadgeVariant.defaultVariant : BloomBadgeVariant.secondary,
              onTap: () => onSelected(option),
            ),
          );
        }).toList(),
      ),
    );
  }
}
