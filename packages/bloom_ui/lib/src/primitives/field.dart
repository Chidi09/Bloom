// lib/src/primitives/field.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomFieldLabel extends StatelessWidget {
  final String? label;
  final Widget? child;
  final bool required;

  const BloomFieldLabel({
    super.key,
    this.label,
    this.child,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final content = child ??
        (label == null
            ? null
            : Text.rich(
                TextSpan(
                  text: label,
                  children: [
                    if (required)
                      TextSpan(
                        text: ' *',
                        style: TextStyle(color: colors.error),
                      ),
                  ],
                ),
              ));

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DefaultTextStyle(
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: context.bloomTypography.sans,
        ),
        child: content ?? const SizedBox.shrink(),
      ),
    );
  }
}

class BloomFieldMessage extends StatelessWidget {
  final String? message;
  final bool error;

  const BloomFieldMessage({
    super.key,
    this.message,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        message ?? '',
        style: TextStyle(
          color: error ? colors.error : colors.textSecondary,
          fontSize: 12,
          fontFamily: context.bloomTypography.sans,
        ),
      ),
    );
  }
}

class BloomFormField<T> extends StatelessWidget {
  final Widget label;
  final Widget child;
  final Widget? message;
  final String? errorText;
  final String? helperText;
  final bool showError;

  const BloomFormField({
    super.key,
    required this.label,
    required this.child,
    this.message,
    this.errorText,
    this.helperText,
    this.showError = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = showError && errorText != null;

    final bottom = message ??
        (hasError
            ? BloomFieldMessage(message: errorText, error: true)
            : helperText != null
                ? BloomFieldMessage(message: helperText)
                : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        label,
        child,
        if (bottom != null) bottom,
      ],
    );
  }
}
