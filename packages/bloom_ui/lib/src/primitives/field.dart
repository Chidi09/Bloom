// lib/src/primitives/field.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

/// Form field wrapper matching shadcn/ui base-nova field architecture.
class BloomField extends StatelessWidget {
  final Widget? label;
  final Widget? description;
  final Widget? error;
  final Widget child;
  final Axis orientation;
  final bool required;

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

/// Field label
class BloomFieldLabel extends StatelessWidget {
  final String text;
  final bool required;

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

/// Field description/helper text
class BloomFieldDescription extends StatelessWidget {
  final String text;
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

/// Field error message
class BloomFieldError extends StatelessWidget {
  final String text;
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

/// Group of related fields
class BloomFieldGroup extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

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

/// Field Legend
class BloomFieldLegend extends StatelessWidget {
  final String text;
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
