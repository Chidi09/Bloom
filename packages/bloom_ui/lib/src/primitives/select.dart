// lib/src/primitives/select.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'input.dart';

/// An item entry for [BloomSelect] representing a selectable option.
///
/// Contains the underlying [value], user-facing [label], and optional leading [icon].
class BloomSelectItem<T> {
  /// The value associated with this item.
  final T value;

  /// The human-readable text label displayed in the dropdown menu.
  final String label;

  /// An optional leading icon displayed beside the label.
  final Widget? icon;

  /// Creates a [BloomSelectItem].
  const BloomSelectItem({
    required this.value,
    required this.label,
    this.icon,
  });
}

/// A dropdown select input field primitive styled according to Bloom design tokens.
///
/// Wraps [DropdownButtonFormField] with consistent input borders, text styles, and dropdown menus.
///
/// ```dart
/// BloomSelect<String>(
///   value: selectedRole,
///   hintText: 'Select a role',
///   items: const [
///     BloomSelectItem(value: 'admin', label: 'Admin'),
///     BloomSelectItem(value: 'user', label: 'User'),
///   ],
///   onChanged: (val) => setState(() => selectedRole = val),
/// )
/// ```
class BloomSelect<T> extends StatelessWidget {
  /// The currently selected value, matching one of the [items]' values.
  final T? value;

  /// The list of selectable items displayed in the dropdown menu.
  final List<BloomSelectItem<T>> items;

  /// Callback invoked when the user selects an option.
  final ValueChanged<T?>? onChanged;

  /// Optional placeholder text shown when no item is selected.
  final String? hintText;

  /// Optional label text displayed as the input decoration label.
  final String? labelText;

  /// Whether the select input is disabled and non-interactive.
  final bool disabled;

  /// Creates a [BloomSelect].
  const BloomSelect({
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

    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items.map((item) {
        return DropdownMenuItem<T>(
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
                  color: colors.textPrimary,
                  fontSize: 14,
                  fontFamily: context.bloomTypography.sans,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: disabled ? null : onChanged,
      dropdownColor: colors.surface1,
      icon: Icon(Icons.keyboard_arrow_down, color: colors.textSecondary, size: 20),
      decoration: bloomInputDecoration(
        context,
        hintText: hintText,
        labelText: labelText,
      ),
    );
  }
}
