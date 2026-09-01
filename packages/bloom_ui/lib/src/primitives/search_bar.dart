// lib/src/primitives/search_bar.dart
import 'package:flutter/widgets.dart';

import '../icons/bloom_icon.dart';
import '../icons/bloom_icons.dart';
import '../utils/bloom_editable_field.dart';
import '../utils/bloom_pressable.dart';
import '../utils/extensions.dart';

class BloomSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final String hintText;

  const BloomSearchBar({
    super.key,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.hintText = 'Search...',
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    final suffix = controller != null && controller!.text.isNotEmpty
        ? BloomPressable(
            borderRadius: BorderRadius.circular(context.bloomRadius.sm),
            padding: const EdgeInsets.all(4),
            onTap: () {
              controller!.clear();
              onClear?.call();
              onChanged?.call('');
            },
            child: BloomIcon(BloomIcons.clear, size: 16, color: colors.textSecondary),
          )
        : null;

    return BloomEditableField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 14,
        fontFamily: context.bloomTypography.sans,
      ),
      placeholder: hintText,
      placeholderStyle: TextStyle(
        color: colors.textTertiary,
        fontSize: 14,
        fontFamily: context.bloomTypography.sans,
      ),
      prefix: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: BloomIcon(BloomIcons.search, size: 20, color: colors.textSecondary),
      ),
      suffix: suffix,
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(context.bloomRadius.md),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
