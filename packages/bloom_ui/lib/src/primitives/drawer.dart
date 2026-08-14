// lib/src/primitives/drawer.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomDrawer extends StatelessWidget {
  final Widget? header;
  final List<Widget> children;
  final Widget? footer;

  const BloomDrawer({
    super.key,
    this.header,
    required this.children,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Drawer(
      backgroundColor: colors.surface1,
      child: SafeArea(
        child: Column(
          children: [
            if (header != null) ...[
              header!,
              Divider(color: colors.border),
            ],
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                children: children,
              ),
            ),
            if (footer != null) ...[
              Divider(color: colors.border),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}
