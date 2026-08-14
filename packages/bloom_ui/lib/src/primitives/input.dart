// lib/src/primitives/input.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

/// Clean text input decoration matching shadcn/ui base-nova 32px height scale.
InputDecoration bloomInputDecoration(
  BuildContext context, {
  String? placeholder,
  String? hintText,
  String? labelText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? errorText,
  bool dense = true,
  bool filled = false,
  Color? fillColor,
}) {
  final colors = context.bloomColors;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final effectiveHint = placeholder ?? hintText;

  return InputDecoration(
    hintText: effectiveHint,
    labelText: labelText,
    hintStyle: TextStyle(
      color: colors.textTertiary,
      fontSize: 14,
      fontFamily: context.bloomTypography.sans,
      fontWeight: FontWeight.w400,
    ),
    labelStyle: TextStyle(
      color: colors.textSecondary,
      fontSize: 14,
      fontFamily: context.bloomTypography.sans,
    ),
    prefixIcon: prefixIcon != null
        ? Padding(padding: const EdgeInsets.only(left: 10, right: 8), child: prefixIcon)
        : null,
    prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    suffixIcon: suffixIcon != null
        ? Padding(padding: const EdgeInsets.only(left: 8, right: 10), child: suffixIcon)
        : null,
    suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    errorText: errorText,
    errorStyle: TextStyle(
      color: colors.error,
      fontSize: 12,
      fontFamily: context.bloomTypography.sans,
    ),
    isDense: dense,
    filled: filled || isDark,
    fillColor: fillColor ?? (isDark ? colors.border.withValues(alpha: 0.15) : Colors.transparent),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.bloomRadius.md),
      borderSide: BorderSide(color: colors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.bloomRadius.md),
      borderSide: BorderSide(color: colors.ring, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.bloomRadius.md),
      borderSide: BorderSide(color: colors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.bloomRadius.md),
      borderSide: BorderSide(color: colors.error, width: 1.5),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(context.bloomRadius.md),
      borderSide: BorderSide(color: colors.border.withValues(alpha: 0.5)),
    ),
  );
}

/// Standalone text field input component
class BloomInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String? placeholder;
  final String? hintText;
  final String? label;
  final String? error;
  final bool obscureText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? leading;
  final Widget? trailing;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool autofocus;
  final bool enabled;
  final FocusNode? focusNode;

  const BloomInput({
    super.key,
    this.controller,
    this.initialValue,
    this.placeholder,
    this.hintText,
    this.label,
    this.error,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.onSubmitted,
    this.leading,
    this.trailing,
    this.prefixIcon,
    this.suffixIcon,
    this.autofocus = false,
    this.enabled = true,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final effectiveHint = placeholder ?? hintText;
    final effectivePrefix = leading ?? prefixIcon;
    final effectiveSuffix = trailing ?? suffixIcon;

    final field = SizedBox(
      height: 32, // h-8
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        autofocus: autofocus,
        enabled: enabled,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 14,
          fontFamily: context.bloomTypography.sans,
        ),
        cursorColor: colors.primary,
        cursorWidth: 1.5,
        decoration: bloomInputDecoration(
          context,
          placeholder: effectiveHint,
          prefixIcon: effectivePrefix,
          suffixIcon: effectiveSuffix,
          errorText: null,
          dense: true,
        ),
      ),
    );

    if (label != null || error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: context.bloomTypography.sans,
              ),
            ),
            const SizedBox(height: 6),
          ],
          field,
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(
              error!,
              style: TextStyle(
                color: colors.error,
                fontSize: 12,
                fontFamily: context.bloomTypography.sans,
              ),
            ),
          ],
        ],
      );
    }

    return field;
  }
}
