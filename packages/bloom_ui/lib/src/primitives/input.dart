// lib/src/primitives/input.dart
import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';
import '../utils/bloom_editable_field.dart';
import '../utils/extensions.dart';

/// Clean box decoration for inputs matching shadcn/ui base-nova 32px height scale.
BoxDecoration bloomInputDecoration(
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
  bool error = false,
  bool focused = false,
  bool disabled = false,
}) {
  final colors = context.bloomColors;
  final isDark = colors.brightness == Brightness.dark;
  final hasError = error || errorText != null;

  final Color effectiveBorderColor;
  final double borderWidth;
  if (hasError) {
    effectiveBorderColor = colors.error;
    borderWidth = focused ? 1.5 : 1.0;
  } else if (focused) {
    effectiveBorderColor = colors.ring;
    borderWidth = 1.5;
  } else if (disabled) {
    effectiveBorderColor = colors.border.withValues(alpha: 0.5);
    borderWidth = 1.0;
  } else {
    effectiveBorderColor = colors.border;
    borderWidth = 1.0;
  }

  final Color effectiveFill = fillColor ??
      (filled || isDark
          ? colors.border.withValues(alpha: 0.15)
          : BloomColors.transparent);

  return BoxDecoration(
    color: effectiveFill,
    borderRadius: BorderRadius.circular(context.bloomRadius.md),
    border: Border.all(color: effectiveBorderColor, width: borderWidth),
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
  final FormFieldValidator<String>? validator;
  final FormFieldSetter<String>? onSaved;
  final AutovalidateMode? autovalidateMode;

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
    this.validator,
    this.onSaved,
    this.autovalidateMode,
  });

  Widget _buildField(
    BuildContext context, {
    String? errorText,
    ValueChanged<String>? onFieldChanged,
  }) {
    final colors = context.bloomColors;
    final isDark = colors.brightness == Brightness.dark;
    final effectiveHint = placeholder ?? hintText;
    final effectivePrefix = leading ?? prefixIcon;
    final effectiveSuffix = trailing ?? suffixIcon;
    final hasError = errorText != null || error != null;

    final effectiveDecoration = BoxDecoration(
      color: isDark ? colors.border.withValues(alpha: 0.15) : BloomColors.transparent,
      borderRadius: BorderRadius.circular(context.bloomRadius.md),
      border: Border.all(
        color: hasError
            ? colors.error
            : (enabled ? colors.border : colors.border.withValues(alpha: 0.5)),
        width: 1.0,
      ),
    );

    final prefixWidget = effectivePrefix != null
        ? Padding(
            padding: const EdgeInsets.only(left: 10, right: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              child: Center(child: effectivePrefix),
            ),
          )
        : null;

    final suffixWidget = effectiveSuffix != null
        ? Padding(
            padding: const EdgeInsets.only(left: 8, right: 10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              child: Center(child: effectiveSuffix),
            ),
          )
        : null;

    return SizedBox(
      height: 32, // h-8
      child: BloomEditableField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        onChanged: (val) {
          onChanged?.call(val);
          onFieldChanged?.call(val);
        },
        onSubmitted: onSubmitted,
        autofocus: autofocus,
        enabled: enabled,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 14,
          fontFamily: context.bloomTypography.sans,
        ),
        placeholder: effectiveHint,
        placeholderStyle: TextStyle(
          color: colors.textTertiary,
          fontSize: 14,
          fontFamily: context.bloomTypography.sans,
          fontWeight: FontWeight.w400,
        ),
        cursorColor: colors.primary,
        cursorWidth: 1.5,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: effectiveDecoration,
        prefix: prefixWidget,
        suffix: suffixWidget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    if (validator != null || onSaved != null) {
      return FormField<String>(
        initialValue: controller?.text ?? initialValue ?? '',
        validator: validator,
        onSaved: onSaved,
        autovalidateMode: autovalidateMode,
        builder: (FormFieldState<String> state) {
          final effectiveError = error ?? state.errorText;
          final inputWidget = _buildField(
            context,
            errorText: effectiveError,
            onFieldChanged: (value) => state.didChange(value),
          );

          if (label != null || effectiveError != null) {
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
                inputWidget,
                if (effectiveError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    effectiveError,
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
          return inputWidget;
        },
      );
    }

    final field = _buildField(context);

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
