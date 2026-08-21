// lib/src/primitives/field.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

/// A versatile form field container component matching shadcn/ui base-nova field architecture.
///
/// Supports vertical and horizontal layouts ([orientation]), custom label widgets,
/// helper descriptions, error messages, and required indicator styling.
///
/// ```dart
/// BloomField(
///   label: const BloomFieldLabel('Email address', required: true),
///   description: const BloomFieldDescription('We will never share your email.'),
///   error: hasError ? const BloomFieldError('Invalid email format') : null,
///   child: BloomInput(controller: emailController),
/// )
/// ```
class BloomField extends StatelessWidget {
  /// Optional label widget displayed alongside or above the field input.
  final Widget? label;

  /// Optional helper or description widget displayed below the input.
  final Widget? description;

  /// Optional validation error widget displayed below the input or description.
  final Widget? error;

  /// The input control widget (e.g. [BloomInput], [BloomSwitch], [BloomSlider]).
  final Widget child;

  /// The layout orientation of the field container.
  ///
  /// Defaults to [Axis.vertical]. When [Axis.horizontal], the label is placed on the left.
  final Axis orientation;

  /// Whether this field is marked as required.
  ///
  /// Defaults to `false`.
  final bool required;

  /// Creates a [BloomField].
  const BloomField({
    super.key,
    this.label,
    this.description,
    this.error,
    required this.child,
    this.orientation = Axis.vertical,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    if (orientation == Axis.horizontal) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (label != null) ...[
            SizedBox(
              width: 120,
              child: label!,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                child,
                if (description != null) ...[
                  const SizedBox(height: 4),
                  description!,
                ],
                if (error != null) ...[
                  const SizedBox(height: 4),
                  error!,
                ],
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          label!,
          const SizedBox(height: 6),
        ],
        child,
        if (description != null) ...[
          const SizedBox(height: 4),
          description!,
        ],
        if (error != null) ...[
          const SizedBox(height: 4),
          error!,
        ],
      ],
    );
  }
}

/// A standard typography label for form fields with optional red asterisk indicator for required fields.
///
/// ```dart
/// BloomFieldLabel('Full Name', required: true)
/// ```
class BloomFieldLabel extends StatelessWidget {
  /// The label text string.
  final String text;

  /// Whether to display a destructive colored asterisk `*` indicating a required field.
  ///
  /// Defaults to `false`.
  final bool required;

  /// Creates a [BloomFieldLabel].
  const BloomFieldLabel(this.text, {super.key, this.required = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            fontFamily: context.bloomTypography.sans,
            letterSpacing: -0.1,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 3),
          Text(
            '*',
            style: TextStyle(
              color: colors.destructive,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Secondary helper description text displayed underneath a field.
///
/// ```dart
/// BloomFieldDescription('Passwords must be at least 8 characters long.')
/// ```
class BloomFieldDescription extends StatelessWidget {
  /// The helper description message text.
  final String text;

  /// Creates a [BloomFieldDescription].
  const BloomFieldDescription(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.bloomColors.textTertiary,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        fontFamily: context.bloomTypography.sans,
      ),
    );
  }
}

/// Form field error message styled in destructive/error colors.
///
/// ```dart
/// BloomFieldError('Please enter a valid credit card number.')
/// ```
class BloomFieldError extends StatelessWidget {
  /// The error message text.
  final String text;

  /// Creates a [BloomFieldError].
  const BloomFieldError(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.bloomColors.destructive,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        fontFamily: context.bloomTypography.sans,
      ),
    );
  }
}

/// A vertical layout container for grouping multiple related [BloomField] components with uniform spacing.
///
/// ```dart
/// BloomFieldGroup(
///   spacing: 20,
///   children: [
///     BloomField(
///       label: const BloomFieldLabel('First Name'),
///       child: BloomInput(),
///     ),
///     BloomField(
///       label: const BloomFieldLabel('Last Name'),
///       child: BloomInput(),
///     ),
///   ],
/// )
/// ```
class BloomFieldGroup extends StatelessWidget {
  /// The list of child form field widgets.
  final List<Widget> children;

  /// The vertical spacing applied between child fields.
  ///
  /// Defaults to `16.0`.
  final double spacing;

  /// Creates a [BloomFieldGroup].
  const BloomFieldGroup({super.key, required this.children, this.spacing = 16});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children
          .map((c) => Padding(padding: EdgeInsets.only(bottom: spacing), child: c))
          .toList(),
    );
  }
}

/// A section heading legend for a set of related form fields.
///
/// ```dart
/// BloomFieldLegend('Billing Information')
/// ```
class BloomFieldLegend extends StatelessWidget {
  /// The heading title text.
  final String text;

  /// Creates a [BloomFieldLegend].
  const BloomFieldLegend(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.bloomColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFamily: context.bloomTypography.sans,
      ),
    );
  }
}
