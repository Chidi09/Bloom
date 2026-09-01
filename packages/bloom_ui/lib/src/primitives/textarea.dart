// lib/src/primitives/textarea.dart
import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import '../utils/bloom_editable_field.dart';
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
    final isDark = colors.brightness == Brightness.dark;

    final decoration = BoxDecoration(
      color: isDark ? colors.border.withValues(alpha: 0.15) : BloomColors.transparent,
      borderRadius: BorderRadius.circular(context.bloomRadius.md),
      border: Border.all(
        color: enabled ? colors.border : colors.border.withValues(alpha: 0.5),
      ),
    );

    return BloomEditableField(
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
      placeholder: placeholder,
      placeholderStyle: TextStyle(
        color: colors.textTertiary,
        fontSize: 14,
        fontFamily: context.bloomTypography.sans,
      ),
      cursorColor: colors.primary,
      cursorWidth: 1.5,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: decoration,
    );
  }
}
