// lib/src/primitives/hover_card.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

/// A hover- and tap-activated preview card popup component.
///
/// Displays a rich content card overlay adjacent to a [trigger] widget when the
/// user hovers with a pointer device or taps on touch interfaces. The overlay
/// automatically hides when the pointer leaves the card area or when tapped again.
///
/// Example:
/// ```dart
/// BloomHoverCard(
///   trigger: Text(
///     '@bloom_ui',
///     style: TextStyle(decoration: TextDecoration.underline),
///   ),
///   content: Column(
///     mainAxisSize: MainAxisSize.min,
///     crossAxisAlignment: CrossAxisAlignment.start,
///     children: const [
///       Text('Bloom UI', style: TextStyle(fontWeight: FontWeight.bold)),
///       SizedBox(height: 4),
///       Text('Modern design primitives built for high performance.'),
///     ],
///   ),
/// );
/// ```
class BloomHoverCard extends StatefulWidget {
  /// The anchor widget that triggers the hover card popup.
  final Widget trigger;

  /// The preview content displayed inside the floating card popup.
  final Widget content;

  /// Fixed width of the floating preview card. Defaults to `280`.
  final double width;

  /// Creates a [BloomHoverCard].
  ///
  /// * [trigger]: The widget monitored for hover and tap interactions.
  /// * [content]: The preview content displayed inside the popover.
  /// * [width]: Width in logical pixels (defaults to `280`).
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

