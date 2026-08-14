// lib/src/primitives/form.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'label.dart';

class BloomForm extends StatelessWidget {
  final GlobalKey<FormState>? formKey;
  final Widget child;
  final AutovalidateMode? autovalidateMode;

  const BloomForm({
    super.key,
    this.formKey,
    required this.child,
    this.autovalidateMode,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      autovalidateMode: autovalidateMode,
      child: child,
    );
  }
}

class BloomFormField extends StatelessWidget {
  final String? label;
  final bool required;
  final Widget child;
  final String? message;
  final String? description;

  const BloomFormField({
    super.key,
    this.label,
    this.required = false,
    required this.child,
    this.message,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) BloomLabel(label!, required: required),
          child,
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description!,
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
          ],
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              style: TextStyle(color: colors.error, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
