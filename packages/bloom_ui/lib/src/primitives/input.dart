// lib/src/primitives/input.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

InputDecoration bloomInputDecoration(
  BuildContext context, {
  String? hintText,
  String? labelText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? errorText,
}) {
  final theme = context.bloomTheme;
  final colors = theme.colors;
  final radius = BorderRadius.circular(theme.radius.md);

  return InputDecoration(
    filled: true,
    fillColor: colors.surface2,
    hintText: hintText,
    labelText: labelText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    errorText: errorText,
    hintStyle: TextStyle(color: colors.textTertiary, fontSize: 14),
    labelStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: colors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: colors.border)),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: colors.error)),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colors.error, width: 1.5),
    ),
  );
}

class BloomInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String? hintText;
  final String? labelText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;

  const BloomInput({
    super.key,
    this.controller,
    this.initialValue,
    this.hintText,
    this.labelText,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: enabled,
      autofocus: autofocus,
      focusNode: focusNode,
      onChanged: onChanged,
      validator: validator,
      style: TextStyle(
        color: context.bloomColors.textPrimary,
        fontSize: 14,
        fontFamily: context.bloomTypography.sans,
      ),
      decoration: bloomInputDecoration(
        context,
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
