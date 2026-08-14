// lib/src/primitives/progress.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

/// Linear progress bar matching shadcn/ui base-nova 4px height scale.
class BloomProgress extends StatelessWidget {
  final double? value;
  final double height;
  final Color? backgroundColor;
  final Color? color;

  const BloomProgress({
    super.key,
    this.value,
    this.height = 4.0, // h-1 (4px)
    this.backgroundColor,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: backgroundColor ?? colors.surface0, // bg-muted
        child: value != null
            ? FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value!.clamp(0.0, 1.0),
                child: Container(
                  color: color ?? colors.primary,
                ),
              )
            : LinearProgressIndicator(
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(color ?? colors.primary),
                minHeight: height,
              ),
      ),
    );
  }
}

class BloomProgressLabel extends StatelessWidget {
  final String text;
  const BloomProgressLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        fontFamily: context.bloomTypography.sans,
        color: context.bloomColors.textPrimary,
      ),
    );
  }
}

class BloomProgressValue extends StatelessWidget {
  final String text;
  const BloomProgressValue(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        fontFamily: context.bloomTypography.mono,
        color: context.bloomColors.textSecondary,
      ),
    );
  }
}
