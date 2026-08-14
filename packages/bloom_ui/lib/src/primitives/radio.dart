// lib/src/primitives/radio.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

class BloomRadio<T> extends StatelessWidget {
  final T value;
  final T? groupValue;
  final ValueChanged<T>? onChanged;
  final Widget? label;
  final String? description;
  final bool disabled;

  const BloomRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.label,
    this.description,
    this.disabled = false,
  });

  bool get isSelected => value == groupValue;

  void _select() {
    if (disabled || onChanged == null) return;
    onChanged!(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    final circle = AnimatedContainer(
      duration: BloomMotion.instant,
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? colors.primary : colors.border,
          width: isSelected ? 5.5 : 1.5,
        ),
      ),
    );

    if (label == null) {
      return GestureDetector(onTap: _select, child: circle);
    }

    return GestureDetector(
      onTap: _select,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2.0), child: circle),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle(
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  child: label!,
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description!,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BloomRadioGroup<T> extends StatelessWidget {
  final List<BloomRadio<T>> children;
  final double spacing;

  const BloomRadioGroup({
    super.key,
    required this.children,
    this.spacing = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.map((r) => Padding(
        padding: EdgeInsets.only(bottom: spacing),
        child: r,
      )).toList(),
    );
  }
}
