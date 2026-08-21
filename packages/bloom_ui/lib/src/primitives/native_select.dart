// lib/src/primitives/native_select.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

/// An item entry for [BloomNativeSelect].
///
/// Holds the underlying [value] and user-facing [label] text.
class BloomNativeSelectItem<T> {
  /// The value associated with this item.
  final T value;

  /// The text label displayed for this item in the select menu.
  final String label;

  /// Creates a [BloomNativeSelectItem].
  const BloomNativeSelectItem({
    required this.value,
    required this.label,
  });
}

/// A compact native styled dropdown select button primitive.
///
/// Renders a framed container with subtle border, surface background, and an arrow indicator.
///
/// ```dart
/// BloomNativeSelect<String>(
///   value: selectedCountry,
///   hintText: 'Select country',
///   items: const [
///     BloomNativeSelectItem(value: 'us', label: 'United States'),
///     BloomNativeSelectItem(value: 'ca', label: 'Canada'),
///   ],
///   onChanged: (val) => setState(() => selectedCountry = val),
/// )
/// ```
class BloomNativeSelect<T> extends StatelessWidget {
  /// The currently selected value, matching one of the [items]' values.
  final T? value;

  /// The list of selectable items.
  final List<BloomNativeSelectItem<T>> items;

  /// Callback invoked when an item is selected.
  final ValueChanged<T?>? onChanged;

  /// Optional placeholder text displayed when [value] is null.
  final String? hintText;

  /// Optional label text descriptor.
  final String? labelText;

  /// Whether the select is disabled and non-interactive.
  final bool disabled;

  /// Creates a [BloomNativeSelect].
  const BloomNativeSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hintText,
    this.labelText,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Semantics(
      enabled: !disabled,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: BorderRadius.circular(context.bloomRadius.md),
          border: Border.all(color: colors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            disabledHint: hintText != null
                ? Text(
                    hintText!,
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 14,
                      fontFamily: context.bloomTypography.sans,
                    ),
                  )
                : null,
            hint: hintText != null
                ? Text(
                    hintText!,
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 14,
                      fontFamily: context.bloomTypography.sans,
                    ),
                  )
                : null,
            items: items.map((item) {
              return DropdownMenuItem<T>(
                value: item.value,
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontFamily: context.bloomTypography.sans,
                  ),
                ),
              );
            }).toList(),
            onChanged: disabled ? null : onChanged,
            dropdownColor: colors.surface1,
            icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary, size: 20),
          ),
        ),
      ),
    );
  }
}
