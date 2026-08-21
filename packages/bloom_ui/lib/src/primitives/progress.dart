// lib/src/primitives/progress.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

/// A linear progress bar indicator matching shadcn/ui base-nova 4px height scale.
///
/// Supports determinate progress when [value] is provided (between `0.0` and `1.0`)
/// or indeterminate animation when [value] is null.
///
/// ```dart
/// // Determinate progress at 65%
/// BloomProgress(value: 0.65);
///
/// // Indeterminate loading progress
/// BloomProgress();
/// ```
class BloomProgress extends StatelessWidget {
  /// The progress value between `0.0` and `1.0`.
  ///
  /// If null, displays an indeterminate animated progress bar.
  final double? value;

  /// The height of the progress bar in logical pixels.
  ///
  /// Defaults to `4.0` (4px height scale).
  final double height;

  /// The background track color of the progress bar.
  ///
  /// Defaults to [BloomColorScheme.surface0] (muted background).
  final Color? backgroundColor;

  /// The fill color of the active progress indicator bar.
  ///
  /// Defaults to [BloomColorScheme.primary].
  final Color? color;

  /// Creates a [BloomProgress] bar.
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

/// A text label displayed adjacent to or above a [BloomProgress] bar.
///
/// Formats text using the theme's sans font family with medium font weight.
///
/// ```dart
/// BloomProgressLabel('Downloading updates...');
/// ```
class BloomProgressLabel extends StatelessWidget {
  /// The descriptive label text.
  final String text;

  /// Creates a [BloomProgressLabel].
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

/// A numeric or percentage label displayed alongside a [BloomProgress] bar.
///
/// Formats text using the theme's monospaced font family for aligned tabular digits.
///
/// ```dart
/// BloomProgressValue('65%');
/// ```
class BloomProgressValue extends StatelessWidget {
  /// The formatted progress value text.
  final String text;

  /// Creates a [BloomProgressValue].
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
