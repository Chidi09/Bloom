// lib/src/primitives/multi_select.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'badge.dart';
import 'checkbox.dart';
import 'sheet.dart';

/// A multi-selection input widget displaying selected items as removable badges
/// and opening a bottom sheet to toggle options.
///
/// Example:
/// ```dart
/// BloomMultiSelect<String>(
///   allValues: ['Design', 'Engineering', 'Marketing'],
///   selectedValues: selectedTags,
///   labelBuilder: (tag) => tag,
///   onChanged: (newTags) => setState(() => selectedTags = newTags),
/// )
/// ```
class BloomMultiSelect<T> extends StatelessWidget {
  /// The currently selected values.
  final List<T> selectedValues;

  /// The complete list of available values to select from.
  final List<T> allValues;

  /// Function to generate human-readable string labels for each item.
  final String Function(T item) labelBuilder;

  /// Callback fired when the selection changes.
  final ValueChanged<List<T>> onChanged;

  /// Placeholder text displayed when no items are selected. Defaults to `'Select options...'`.
  final String placeholder;

  /// Creates a [BloomMultiSelect].
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
      side: BloomSheetSide.bottom,
      builder: (context) {
        return BloomSheet(
          side: BloomSheetSide.bottom,
          header: const BloomSheetHeader(
            title: BloomSheetTitle('Select Options'),
          ),
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
                        if (val == true) {
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return GestureDetector(
      onTap: () => _showSelector(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surface1,
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
