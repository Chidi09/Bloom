// lib/src/primitives/search_bar.dart
import 'package:flutter/material.dart';
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

    return Container(
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(context.bloomRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 14,
          fontFamily: context.bloomTypography.sans,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: colors.textTertiary, fontSize: 14),
          prefixIcon: Icon(Icons.search, size: 20, color: colors.textSecondary),
          suffixIcon: controller != null && controller!.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 16, color: colors.textSecondary),
                  onPressed: () {
                    controller!.clear();
                    onClear?.call();
                    onChanged?.call('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
