// lib/src/primitives/popover.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

class BloomPopover extends StatelessWidget {
  final Widget trigger;
  final Widget content;
  final double width;

  const BloomPopover({
    super.key,
    required this.trigger,
    required this.content,
    this.width = 280,
  });

  void _showPopover(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            GestureDetector(
              onTap: () => entry.remove(),
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
            Positioned(
              left: offset.dx,
              top: offset.dy + size.height + 8,
              width: width,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.bloomColors.surface1,
                    borderRadius: BorderRadius.circular(context.bloomRadius.md),
                    border: Border.all(color: context.bloomColors.border),
                    boxShadow: const [BloomShadows.s3],
                  ),
                  child: content,
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPopover(context),
      child: trigger,
    );
  }
}
