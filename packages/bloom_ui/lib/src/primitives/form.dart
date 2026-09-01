// lib/src/primitives/form.dart
import 'package:flutter/widgets.dart';

import '../utils/extensions.dart';
import 'label.dart';

/// A wrapper around Flutter's [Form] integrating Bloom design patterns and validation modes.
///
/// ```dart
/// final formKey = GlobalKey<FormState>();
///
/// BloomForm(
///   formKey: formKey,
///   child: Column(
///     children: [
///       BloomFormField(
///         label: 'Email',
///         required: true,
///         child: BloomInput(hintText: 'user@example.com'),
///       ),
///     ],
///   ),
/// )
/// ```
class BloomForm extends StatelessWidget {
  /// The global key used to validate and save the underlying form state.
  final GlobalKey<FormState>? formKey;

  /// The child subtree containing form field inputs.
  final Widget child;

  /// Used to enable/disable auto validation and determine when it happens.
  final AutovalidateMode? autovalidateMode;

  /// Creates a [BloomForm].
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

/// A structured form field container presenting a label, an input [child], a helper [description], and an error [message].
///
/// Automatically formats the layout in a vertical column with proper spacing and color tokens.
///
/// ```dart
/// BloomFormField(
///   label: 'Username',
///   required: true,
///   description: 'Your public display name',
///   message: errorMessage,
///   child: BloomInput(controller: usernameController),
/// )
/// ```
class BloomFormField extends StatelessWidget {
  /// Optional label text rendered above the field input using [BloomLabel].
  final String? label;

  /// Whether to indicate that this field is required (e.g. displaying an asterisk).
  ///
  /// Defaults to `false`.
  final bool required;

  /// The actual input widget (e.g. [BloomInput], [BloomSelect]).
  final Widget child;

  /// Optional error message text rendered below the input with error color.
  final String? message;

  /// Optional helper description text rendered below the input with muted secondary color.
  final String? description;

  /// Creates a [BloomFormField].
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
