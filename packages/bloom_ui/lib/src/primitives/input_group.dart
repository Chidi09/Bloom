// lib/src/primitives/input_group.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';
import 'button.dart';

enum BloomInputGroupAddonAlign {
  inlineStart,
  inlineEnd,
  blockStart,
  blockEnd,
}

/// Composed input container matching shadcn/ui base-nova input-group.
class BloomInputGroup extends StatelessWidget {
  final Widget? leading;
  final Widget? trailing;
  final Widget child;

  const BloomInputGroup({
    super.key,
    this.leading,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Container(
      height: 32, // h-8
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(context.bloomRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) leading!,
          Expanded(child: child),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Addon container for InputGroup
class BloomInputGroupAddon extends StatelessWidget {
  final BloomInputGroupAddonAlign align;
  final Widget child;

  const BloomInputGroupAddon({
    super.key,
    this.align = BloomInputGroupAddonAlign.inlineStart,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: align == BloomInputGroupAddonAlign.inlineStart ? 8 : 4,
        right: align == BloomInputGroupAddonAlign.inlineEnd ? 8 : 4,
      ),
      child: child,
    );
  }
}

/// Text addon in InputGroup
class BloomInputGroupText extends StatelessWidget {
  final String text;
  final Widget? child;

  const BloomInputGroupText({super.key, this.text = '', this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      child: child ??
          Text(
            text,
            style: TextStyle(
              color: context.bloomColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              fontFamily: context.bloomTypography.sans,
            ),
          ),
    );
  }
}

/// Button addon in InputGroup
class BloomInputGroupButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final BloomButtonVariant variant;

  const BloomInputGroupButton({
    super.key,
    required this.child,
    this.onPressed,
    this.variant = BloomButtonVariant.ghost,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: BloomButton(
        variant: variant,
        size: BloomButtonSize.xs,
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}
