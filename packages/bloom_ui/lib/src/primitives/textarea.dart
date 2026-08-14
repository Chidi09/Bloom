// lib/src/primitives/textarea.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

/// Multi-line expanded text area matching shadcn base-nova.
class BloomTextarea extends StatelessWidget {
  final TextEditingController? controller;
  final String? placeholder;
  final int minLines;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final FocusNode? focusNode;

  const BloomTextarea({
    super.key,
    this.controller,
    this.placeholder,
    this.minLines = 3,
    this.maxLines = 8,
    this.onChanged,
    this.enabled = true,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      minLines: minLines,
      maxLines: maxLines,
      onChanged: onChanged,
      enabled: enabled,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 14,
        fontFamily: context.bloomTypography.sans,
      ),
      cursorColor: colors.primary,
      cursorWidth: 1.5,
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: TextStyle(
          color: colors.textTertiary,
          fontSize: 14,
          fontFamily: context.bloomTypography.sans,
        ),
        filled: isDark,
        fillColor: isDark ? colors.border.withValues(alpha: 0.15) : Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.bloomRadius.md),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.bloomRadius.md),
          borderSide: BorderSide(color: colors.ring, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.bloomRadius.md),
          borderSide: BorderSide(color: colors.border.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}
