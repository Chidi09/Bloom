// lib/src/primitives/multi_select.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'badge.dart';
import 'checkbox.dart';
import 'sheet.dart';

class BloomMultiSelect<T> extends StatelessWidget {
  final List<T> selectedValues;
  final List<T> allValues;
  final String Function(T item) labelBuilder;
  final ValueChanged<List<T>> onChanged;
  final String placeholder;

  const BloomMultiSelect({
    super.key,
    required this.selectedValues,
    required this.allValues,
    required this.labelBuilder,
    required this.onChanged,
    this.placeholder = 'Select options...',
  });

  void _showSelector(BuildContext context) {
    BloomSheet.show(
      context: context,
      title: 'Select Options',
      child: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: allValues.map((item) {
              final isChecked = selectedValues.contains(item);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: BloomCheckbox(
                  checked: isChecked,
                  label: Text(labelBuilder(item)),
                  onChanged: (val) {
                    final next = List<T>.from(selectedValues);
                    if (val) {
                      next.add(item);
                    } else {
                      next.remove(item);
                    }
                    onChanged(next);
                    setModalState(() {});
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return GestureDetector(
      onTap: () => _showSelector(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: BorderRadius.circular(context.bloomRadius.md),
          border: Border.all(color: colors.border),
        ),
        child: selectedValues.isEmpty
            ? Text(placeholder, style: TextStyle(color: colors.textTertiary, fontSize: 14))
            : Wrap(
                spacing: 6,
                runSpacing: 6,
                children: selectedValues.map((item) {
                  return BloomBadge(
                    variant: BloomBadgeVariant.secondary,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(labelBuilder(item)),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            final next = List<T>.from(selectedValues)..remove(item);
                            onChanged(next);
                          },
                          child: const Icon(Icons.close, size: 12),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }
}
