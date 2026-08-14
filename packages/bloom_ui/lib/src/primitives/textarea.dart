// lib/src/primitives/textarea.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'input.dart';

class BloomTextarea extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String? hintText;
  final String? labelText;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool enabled;

  const BloomTextarea({
    super.key,
    this.controller,
    this.initialValue,
    this.hintText,
    this.labelText,
    this.minLines = 3,
    this.maxLines = 6,
    this.onChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      minLines: minLines,
      maxLines: maxLines,
      enabled: enabled,
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
      ),
    );
  }
}
