// lib/src/primitives/kbd.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomKbd extends StatelessWidget {
  final String text;

  const BloomKbd({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final theme = context.bloomTheme;

    return Semantics(
      label: text,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: colors.surface2,
          borderRadius: BorderRadius.circular(theme.radius.sm),
          border: Border.all(color: colors.border),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            fontFamily: theme.typography.mono,
          ),
        ),
      ),
    );
  }
}

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
