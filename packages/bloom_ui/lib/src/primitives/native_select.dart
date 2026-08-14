// lib/src/primitives/native_select.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomNativeSelectItem<T> {
  final T value;
  final String label;

  const BloomNativeSelectItem({
    required this.value,
    required this.label,
  });
}

class BloomNativeSelect<T> extends StatelessWidget {
  final T? value;
  final List<BloomNativeSelectItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final String? labelText;
  final bool disabled;

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
