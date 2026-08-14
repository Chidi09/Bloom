// lib/src/primitives/select.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'input.dart';

class BloomSelectItem<T> {
  final T value;
  final String label;
  final Widget? icon;

  const BloomSelectItem({
    required this.value,
    required this.label,
    this.icon,
  });
}

class BloomSelect<T> extends StatelessWidget {
  final T? value;
  final List<BloomSelectItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final String? labelText;
  final bool disabled;

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
      value: value,
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
