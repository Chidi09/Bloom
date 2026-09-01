// lib/src/primitives/kbd.dart
import 'package:flutter/widgets.dart';
import '../utils/extensions.dart';

/// Styled keyboard shortcut indicator matching shadcn base-nova.
class BloomKbd extends StatelessWidget {
  final String text;
  final Widget? child;

  const BloomKbd({super.key, this.text = '', this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Semantics(
      label: text,
      child: Container(
        height: 20, // h-5
        constraints: const BoxConstraints(minWidth: 20),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surface0, // bg-muted
          borderRadius: BorderRadius.circular(4), // rounded-sm
          border: Border.all(color: colors.border.withValues(alpha: 0.6)),
        ),
        child: child ??
            Text(
              text,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFamily: context.bloomTypography.sans,
                letterSpacing: -0.1,
              ),
            ),
      ),
    );
  }
}

/// Group of keyboard shortcuts (e.g. ⌘ + K)
class BloomKbdGroup extends StatelessWidget {
  final List<String> keys;
  final double spacing;

  const BloomKbdGroup({
    super.key,
    required this.keys,
    this.spacing = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: keys.join(' + '),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(keys.length, (i) {
          return Padding(
            padding: EdgeInsets.only(left: i > 0 ? spacing : 0),
            child: BloomKbd(text: keys[i]),
          );
        }),
      ),
    );
  }
}
