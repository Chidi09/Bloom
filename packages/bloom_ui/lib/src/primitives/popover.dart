// lib/src/primitives/popover.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

/// An anchored floating popover overlay component.
///
/// Attaches a floating card overlay to a [trigger] widget using a [LayerLink].
/// Tapping the trigger opens or closes the popover, and tapping anywhere outside
/// dismisses it automatically.
///
/// Example:
/// ```dart
/// BloomPopover(
///   trigger: OutlinedButton(
///     onPressed: null, // trigger handles gesture internally
///     child: const Text('Open Popover'),
///   ),
///   content: Column(
///     mainAxisSize: MainAxisSize.min,
///     crossAxisAlignment: CrossAxisAlignment.start,
///     children: const [
///       BloomPopoverHeader(
///         title: BloomPopoverTitle('Dimensions'),
///         description: BloomPopoverDescription('Set the dimensions for the layer.'),
///       ),
///       Text('Popover body content'),
///     ],
///   ),
/// );
/// ```
class BloomPopover extends StatefulWidget {
  /// The anchor widget that toggles the popover overlay when tapped.
  final Widget trigger;

  /// The content displayed inside the floating popover card.
  final Widget content;

  /// Fixed width of the floating popover card. Defaults to `280`.
  final double width;

  /// Alignment anchor point on the trigger widget. Defaults to [Alignment.bottomLeft].
  final Alignment anchorAlignment;

  /// Alignment anchor point on the popover content. Defaults to [Alignment.topLeft].
  final Alignment popoverAlignment;

  /// Creates an anchored [BloomPopover].
  ///
  /// * [trigger]: The widget that toggles the popover when tapped.
  /// * [content]: The content displayed inside the floating card.
  /// * [width]: Width in logical pixels (defaults to `280`).
  /// * [anchorAlignment]: Point on the trigger to align to (defaults to [Alignment.bottomLeft]).
  /// * [popoverAlignment]: Point on the popover to align to (defaults to [Alignment.topLeft]).
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

/// A standardized header container for [BloomPopover].
class BloomPopoverHeader extends StatelessWidget {
  /// Header title widget, typically a [BloomPopoverTitle].
  final Widget? title;

  /// Header description widget, typically a [BloomPopoverDescription].
  final Widget? description;

  /// Creates a [BloomPopoverHeader] with optional [title] and [description].
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

/// Standardized title typography for [BloomPopoverHeader].
class BloomPopoverTitle extends StatelessWidget {
  /// The title text string.
  final String text;

  /// Creates a [BloomPopoverTitle] displaying [text].
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

/// Standardized description typography for [BloomPopoverHeader].
class BloomPopoverDescription extends StatelessWidget {
  /// The description text string.
  final String text;

  /// Creates a [BloomPopoverDescription] displaying [text].
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

