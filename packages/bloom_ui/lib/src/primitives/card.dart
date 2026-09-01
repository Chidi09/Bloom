// lib/src/primitives/card.dart
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';
import '../utils/bloom_pressable.dart';
import '../utils/extensions.dart';

/// Size variants for [BloomCard] and its subcomponents.
enum BloomCardSize {
  /// Default card padding and typography sizing.
  defaultSize,

  /// Compact card padding and typography sizing.
  sm,
}

/// A composable container card matching shadcn/ui base-nova structure and styles.
///
/// Features structured slots for [header], [content], [child], and [footer],
/// with rounded corners, subtle border, and shadow. Also supports optional [onTap]
/// interaction.
///
/// ```dart
/// BloomCard(
///   header: BloomCardHeader(
///     title: const BloomCardTitle('Project Settings'),
///     description: const BloomCardDescription('Manage your workspace preferences.'),
///   ),
///   content: const BloomCardContent(
///     child: Text('Card body text goes here.'),
///   ),
///   footer: BloomCardFooter(
///     child: BloomButton(child: const Text('Save')),
///   ),
/// );
/// ```
class BloomCard extends StatelessWidget {
  /// The header widget, typically a [BloomCardHeader].
  final Widget? header;

  /// The main content widget, typically a [BloomCardContent].
  final Widget? content;

  /// The footer widget, typically a [BloomCardFooter].
  final Widget? footer;

  /// A direct child widget placed in the body with automatic padding.
  final Widget? child;

  /// The size variant controlling padding. Defaults to [BloomCardSize.defaultSize].
  final BloomCardSize size;

  /// Optional override for the card background color.
  final Color? backgroundColor;

  /// Optional override for the card border color.
  final Color? borderColor;

  /// Optional callback triggered when the card is tapped.
  final VoidCallback? onTap;

  /// Creates a [BloomCard].
  const BloomCard({
    super.key,
    this.header,
    this.content,
    this.footer,
    this.child,
    this.size = BloomCardSize.defaultSize,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final padding = size == BloomCardSize.sm ? 12.0 : 16.0;
    final radius = context.bloomRadius.xl;

    final cardContent = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.surface1,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? colors.border),
        boxShadow: const [BloomShadows.s1],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) header!,
            if (content != null) content!,
            if (child != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding),
                child: child!,
              ),
            if (footer != null) footer!,
          ],
        ),
      ),
    );

    if (onTap != null) {
      return BloomPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: cardContent,
      );
    }

    return cardContent;
  }
}

/// Header slot for [BloomCard] with title, description, and optional right-aligned action.
///
/// ```dart
/// BloomCardHeader(
///   title: const BloomCardTitle('Notifications'),
///   description: const BloomCardDescription('Choose what alerts you receive.'),
///   action: BloomButton(variant: BloomButtonVariant.outline, child: const Text('Edit')),
/// );
/// ```
class BloomCardHeader extends StatelessWidget {
  /// The title widget, typically a [BloomCardTitle].
  final Widget? title;

  /// The description widget, typically a [BloomCardDescription].
  final Widget? description;

  /// An optional right-aligned action widget (e.g. button or menu).
  final Widget? action;

  /// An optional custom child widget replacing standard layout.
  final Widget? child;

  /// The size variant for padding. Defaults to [BloomCardSize.defaultSize].
  final BloomCardSize size;

  /// Creates a [BloomCardHeader].
  const BloomCardHeader({
    super.key,
    this.title,
    this.description,
    this.action,
    this.child,
    this.size = BloomCardSize.defaultSize,
  });

  @override
  Widget build(BuildContext context) {
    final padding = size == BloomCardSize.sm ? 12.0 : 16.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(padding, padding, padding, padding / 2),
      child: child ??
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null) title!,
                    if (description != null) ...[
                      const SizedBox(height: 4),
                      description!,
                    ],
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: 12),
                action!,
              ],
            ],
          ),
    );
  }
}

/// Title typography component for [BloomCard].
///
/// ```dart
/// const BloomCardTitle('Analytics Overview');
/// ```
class BloomCardTitle extends StatelessWidget {
  /// The title text string.
  final String text;

  /// The size variant. Defaults to [BloomCardSize.defaultSize].
  final BloomCardSize size;

  /// Creates a [BloomCardTitle].
  const BloomCardTitle(this.text, {super.key, this.size = BloomCardSize.defaultSize});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: size == BloomCardSize.sm ? 14 : 16,
        fontWeight: FontWeight.w600,
        fontFamily: context.bloomTypography.sans,
        color: context.bloomColors.textPrimary,
        letterSpacing: -0.2,
      ),
    );
  }
}

/// Secondary subtitle description typography component for [BloomCard].
///
/// ```dart
/// const BloomCardDescription('View recent activity and stats.');
/// ```
class BloomCardDescription extends StatelessWidget {
  /// The description text string.
  final String text;

  /// Creates a [BloomCardDescription].
  const BloomCardDescription(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        fontFamily: context.bloomTypography.sans,
        color: context.bloomColors.textSecondary,
        height: 1.4,
      ),
    );
  }
}

/// Action slot wrapper for [BloomCardHeader].
///
/// ```dart
/// BloomCardAction(
///   child: BloomButton(child: const Text('Options')),
/// );
/// ```
class BloomCardAction extends StatelessWidget {
  /// The action widget to wrap.
  final Widget child;

  /// Creates a [BloomCardAction].
  const BloomCardAction({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

/// Content body slot for [BloomCard] with predefined padding.
///
/// ```dart
/// BloomCardContent(
///   child: Text('Main card body content goes here.'),
/// );
/// ```
class BloomCardContent extends StatelessWidget {
  /// The widget content placed inside the body.
  final Widget child;

  /// The size variant for padding. Defaults to [BloomCardSize.defaultSize].
  final BloomCardSize size;

  /// Creates a [BloomCardContent].
  const BloomCardContent({super.key, required this.child, this.size = BloomCardSize.defaultSize});

  @override
  Widget build(BuildContext context) {
    final padding = size == BloomCardSize.sm ? 12.0 : 16.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, padding / 2, padding, padding),
      child: child,
    );
  }
}

/// Styled footer slot for [BloomCard] with subtle tinted background and top border.
///
/// ```dart
/// BloomCardFooter(
///   child: BloomButton(child: const Text('Submit')),
/// );
/// ```
class BloomCardFooter extends StatelessWidget {
  /// The widget content placed inside the footer.
  final Widget child;

  /// The size variant for padding. Defaults to [BloomCardSize.defaultSize].
  final BloomCardSize size;

  /// The horizontal alignment of the footer elements. Defaults to [MainAxisAlignment.end].
  final MainAxisAlignment alignment;

  /// Creates a [BloomCardFooter].
  const BloomCardFooter({
    super.key,
    required this.child,
    this.size = BloomCardSize.defaultSize,
    this.alignment = MainAxisAlignment.end,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final padding = size == BloomCardSize.sm ? 12.0 : 16.0;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface0.withValues(alpha: 0.5),
        border: Border(top: BorderSide(color: colors.border)),
      ),
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding * 0.8),
      child: Row(
        mainAxisAlignment: alignment,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [child],
      ),
    );
  }
}
