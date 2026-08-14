// lib/src/primitives/popover.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

/// Anchored floating popover overlay matching shadcn/ui base-nova.
class BloomPopover extends StatefulWidget {
  final Widget trigger;
  final Widget content;
  final double width;
  final Alignment anchorAlignment;
  final Alignment popoverAlignment;

  const BloomPopover({
    super.key,
    required this.trigger,
    required this.content,
    this.width = 280,
    this.anchorAlignment = Alignment.bottomLeft,
    this.popoverAlignment = Alignment.topLeft,
  });

  @override
  State<BloomPopover> createState() => _BloomPopoverState();
}

class _BloomPopoverState extends State<BloomPopover> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _toggle() {
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _close() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _isOpen = false);
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
          Positioned(
            width: widget.width,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: widget.anchorAlignment,
              followerAnchor: widget.popoverAlignment,
              offset: const Offset(0, 4),
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
        ],
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
      child: GestureDetector(
        onTap: _toggle,
        child: widget.trigger,
      ),
    );
  }
}

class BloomPopoverHeader extends StatelessWidget {
  final Widget? title;
  final Widget? description;
  const BloomPopoverHeader({super.key, this.title, this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) title!,
          if (description != null) ...[
            const SizedBox(height: 2),
            description!,
          ],
        ],
      ),
    );
  }
}

class BloomPopoverTitle extends StatelessWidget {
  final String text;
  const BloomPopoverTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        fontFamily: context.bloomTypography.sans,
        color: context.bloomColors.textPrimary,
      ),
    );
  }
}

class BloomPopoverDescription extends StatelessWidget {
  final String text;
  const BloomPopoverDescription(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        fontFamily: context.bloomTypography.sans,
        color: context.bloomColors.textSecondary,
      ),
    );
  }
}
