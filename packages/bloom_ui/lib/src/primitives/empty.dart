// lib/src/primitives/empty.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

/// An empty state container matching shadcn base-nova dashed border container.
///
/// Provides structured slots for an [icon], [title], [description], and an [action] button,
/// or accepts a custom [child] widget. Rendered inside a subtle muted background with rounded corners.
///
/// ```dart
/// BloomEmpty(
///   icon: const Icon(Icons.inbox_outlined),
///   title: const BloomEmptyTitle('No messages'),
///   description: const BloomEmptyDescription('Your inbox is completely clear.'),
///   action: BloomButton(
///     child: const Text('Refresh'),
///     onPressed: () {},
///   ),
/// );
/// ```
class BloomEmpty extends StatelessWidget {
  /// The icon widget rendered within a styled circular/rounded container.
  final Widget? icon;

  /// The title widget, typically a [BloomEmptyTitle].
  final Widget? title;

  /// The description widget, typically a [BloomEmptyDescription].
  final Widget? description;

  /// An optional action button placed below the description.
  final Widget? action;

  /// An optional custom child widget replacing the default layout.
  final Widget? child;

  /// Creates a [BloomEmpty] state container.
  const BloomEmpty({
    super.key,
    this.icon,
    this.title,
    this.description,
    this.action,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: colors.surface0.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(context.bloomRadius.xl),
        border: Border.all(color: colors.border, style: BorderStyle.solid),
      ),
      child: Center(
        child: child ??
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.surface0,
                      borderRadius: BorderRadius.circular(context.bloomRadius.md),
                    ),
                    alignment: Alignment.center,
                    child: IconTheme(
                      data: IconThemeData(color: colors.textSecondary, size: 20),
                      child: icon!,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (title != null) ...[
                  DefaultTextStyle(
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: context.bloomTypography.sans,
                      letterSpacing: -0.1,
                    ),
                    textAlign: TextAlign.center,
                    child: title!,
                  ),
                ],
                if (description != null) ...[
                  const SizedBox(height: 4),
                  DefaultTextStyle(
                    style: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      fontFamily: context.bloomTypography.sans,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                    child: description!,
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: 16),
                  action!,
                ],
              ],
            ),
      ),
    );
  }
}

/// Title typography wrapper for [BloomEmpty].
///
/// ```dart
/// const BloomEmptyTitle('No results found');
/// ```
class BloomEmptyTitle extends StatelessWidget {
  /// The title text string.
  final String text;

  /// Creates a [BloomEmptyTitle].
  const BloomEmptyTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(text);
}

/// Description typography wrapper for [BloomEmpty].
///
/// ```dart
/// const BloomEmptyDescription('Try adjusting your search filters.');
/// ```
class BloomEmptyDescription extends StatelessWidget {
  /// The description text string.
  final String text;

  /// Creates a [BloomEmptyDescription].
  const BloomEmptyDescription(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(text);
}
