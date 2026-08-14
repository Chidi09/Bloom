// lib/src/primitives/hover_card.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

/// Hover / tap preview card popup matching shadcn base-nova.
class BloomHoverCard extends StatefulWidget {
  final Widget trigger;
  final Widget content;
  final double width;

  const BloomHoverCard({
    super.key,
    required this.trigger,
    required this.content,
    this.width = 280, // w-64 to w-72
  });

  @override
  State<BloomHoverCard> createState() => _BloomHoverCardState();
}

class _BloomHoverCardState extends State<BloomHoverCard> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _show() {
    _overlayEntry?.remove();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (ctx) => Positioned(
        width: widget.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 6),
          child: MouseRegion(
            onEnter: (_) {},
            onExit: (_) => _hide(),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(10), // p-2.5
                decoration: BoxDecoration(
                  color: context.bloomColors.surface1,
                  borderRadius: BorderRadius.circular(context.bloomRadius.lg),
                  border: Border.all(color: context.bloomColors.border),
                  boxShadow: const [BloomShadows.s2],
                ),
                child: widget.content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => _show(),
        onExit: (_) => _hide(),
        child: GestureDetector(
          onTap: () {
            if (_overlayEntry == null) {
              _show();
            } else {
              _hide();
            }
          },
          child: widget.trigger,
        ),
      ),
    );
  }
}
