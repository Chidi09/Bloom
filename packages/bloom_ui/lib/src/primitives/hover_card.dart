// lib/src/primitives/hover_card.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

class BloomHoverCard extends StatefulWidget {
  final Widget trigger;
  final Widget content;
  final Duration openDelay;
  final Duration closeDelay;

  const BloomHoverCard({
    super.key,
    required this.trigger,
    required this.content,
    this.openDelay = const Duration(milliseconds: 300),
    this.closeDelay = const Duration(milliseconds: 200),
  });

  @override
  State<BloomHoverCard> createState() => _BloomHoverCardState();
}

class _BloomHoverCardState extends State<BloomHoverCard> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  bool _isHovering = false;
  bool _isInPopup = false;

  void _showCard() {
    if (_isOpen) return;
    _overlayEntry = OverlayEntry(
      builder: (context) => _HoverCardPopup(
        layerLink: _layerLink,
        content: widget.content,
        onEnter: () {
          _isInPopup = true;
        },
        onLeave: () {
          _isInPopup = false;
          Future.delayed(widget.closeDelay, () {
            if (!_isHovering && !_isInPopup && mounted) _hideCard();
          });
        },
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _hideCard() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isOpen = false);
  }

  @override
  void dispose() {
    _hideCard();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) {
          _isHovering = true;
          Future.delayed(widget.openDelay, () {
            if (_isHovering && mounted) _showCard();
          });
        },
        onExit: (_) {
          _isHovering = false;
          Future.delayed(widget.closeDelay, () {
            if (!_isHovering && !_isInPopup && mounted) _hideCard();
          });
        },
        child: GestureDetector(
          onLongPress: _showCard,
          child: widget.trigger,
        ),
      ),
    );
  }
}

class BloomHoverCardContent extends StatelessWidget {
  final Widget child;

  const BloomHoverCardContent({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: BorderRadius.circular(context.bloomRadius.md),
        border: Border.all(color: colors.border),
        boxShadow: const [BloomShadows.s2],
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 14,
          fontFamily: context.bloomTypography.sans,
        ),
        child: child,
      ),
    );
  }
}

class _HoverCardPopup extends StatelessWidget {
  final LayerLink layerLink;
  final Widget content;
  final VoidCallback onEnter;
  final VoidCallback onLeave;

  const _HoverCardPopup({
    required this.layerLink,
    required this.content,
    required this.onEnter,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      link: layerLink,
      targetAnchor: Alignment.bottomCenter,
      followerAnchor: Alignment.topCenter,
      offset: const Offset(0, 8),
      child: MouseRegion(
        onEnter: (_) => onEnter(),
        onExit: (_) => onLeave(),
        child: content,
      ),
    );
  }
}
