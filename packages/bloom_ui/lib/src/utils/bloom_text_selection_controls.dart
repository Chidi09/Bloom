// lib/src/utils/bloom_text_selection_controls.dart
import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import 'bloom_pressable.dart';
import 'bloom_surface.dart';
import 'extensions.dart';

const double _kHandleRadius = 5.0;
const double _kHandleStemWidth = 2.0;
const double _kHandleStemHeight = 4.0;
const Size _kHandleSize = Size(
  _kHandleRadius * 2,
  _kHandleRadius * 2 + _kHandleStemHeight,
);

/// The shared [BloomTextSelectionControls] instance used by Bloom text fields.
final BloomTextSelectionControls bloomTextSelectionControls = BloomTextSelectionControls();

/// Material-free selection handles for Bloom text fields.
class BloomTextSelectionControls extends TextSelectionControls with TextSelectionHandleControls {
  /// Creates a [BloomTextSelectionControls] instance.
  ///
  /// [TextSelectionControls] has no const constructor, so prefer the shared
  /// [bloomTextSelectionControls] instance over allocating one per build.
  BloomTextSelectionControls();

  @override
  Size getHandleSize(double textLineHeight) => _kHandleSize;

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) {
    return const Offset(_kHandleRadius, 0);
  }

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) {
    final color = context.bloomColors.primary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.translucent,
      child: CustomPaint(
        size: getHandleSize(textLineHeight),
        painter: _BloomHandlePainter(color: color),
      ),
    );
  }
}

class _BloomHandlePainter extends CustomPainter {
  const _BloomHandlePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Draw stem
    canvas.drawRect(
      const Rect.fromLTWH(
        _kHandleRadius - (_kHandleStemWidth / 2),
        0,
        _kHandleStemWidth,
        _kHandleStemHeight,
      ),
      paint,
    );

    // Draw circle
    canvas.drawCircle(
      const Offset(_kHandleRadius, _kHandleStemHeight + _kHandleRadius),
      _kHandleRadius,
      paint,
    );
  }

  @override
  bool shouldRepaint(_BloomHandlePainter oldDelegate) => oldDelegate.color != color;
}

/// Builds a Bloom-styled text selection toolbar for [EditableText.contextMenuBuilder].
Widget bloomContextMenuBuilder(BuildContext context, EditableTextState editableTextState) {
  final List<ContextMenuButtonItem> buttonItems = editableTextState.contextMenuButtonItems;
  if (buttonItems.isEmpty) {
    return const SizedBox.shrink();
  }

  final TextSelectionToolbarAnchors anchors = editableTextState.contextMenuAnchors;

  return CustomSingleChildLayout(
    delegate: _BloomContextMenuLayoutDelegate(anchor: anchors.primaryAnchor),
    child: BloomSurface(
      elevation: 4.0,
      borderRadius: BorderRadius.circular(context.bloomRadius.md),
      color: context.bloomColors.surface1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.bloomRadius.md),
          border: Border.all(color: context.bloomColors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < buttonItems.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1.0,
                  height: 14.0,
                  margin: const EdgeInsets.symmetric(horizontal: 2.0),
                  color: context.bloomColors.border,
                ),
              _BloomContextMenuButton(item: buttonItems[i]),
            ],
          ],
        ),
      ),
    ),
  );
}

class _BloomContextMenuButton extends StatelessWidget {
  const _BloomContextMenuButton({required this.item});

  final ContextMenuButtonItem item;

  String _resolveLabel() {
    if (item.label != null && item.label!.isNotEmpty) {
      return item.label!;
    }
    return switch (item.type) {
      ContextMenuButtonType.cut => 'Cut',
      ContextMenuButtonType.copy => 'Copy',
      ContextMenuButtonType.paste => 'Paste',
      ContextMenuButtonType.selectAll => 'Select All',
      ContextMenuButtonType.delete => 'Delete',
      ContextMenuButtonType.lookUp => 'Look Up',
      ContextMenuButtonType.searchWeb => 'Search Web',
      ContextMenuButtonType.share => 'Share',
      ContextMenuButtonType.liveTextInput => 'Live Text',
      ContextMenuButtonType.custom => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final label = _resolveLabel();
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }

    return BloomPressable(
      onTap: item.onPressed,
      borderRadius: BorderRadius.circular(context.bloomRadius.sm),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
      child: Text(
        label,
        style: TextStyle(
          color: context.bloomColors.textPrimary,
          fontSize: context.bloomTypography.sm,
          fontFamily: context.bloomTypography.sans,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _BloomContextMenuLayoutDelegate extends SingleChildLayoutDelegate {
  _BloomContextMenuLayoutDelegate({required this.anchor});

  final Offset anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return constraints.loosen();
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double x = anchor.dx - childSize.width / 2.0;
    if (x < 8.0) {
      x = 8.0;
    }
    if (x + childSize.width > size.width - 8.0) {
      x = math.max(8.0, size.width - childSize.width - 8.0);
    }

    double y = anchor.dy - childSize.height - 8.0;
    if (y < 8.0) {
      y = anchor.dy + 8.0;
    }
    if (y + childSize.height > size.height - 8.0) {
      y = math.max(8.0, size.height - childSize.height - 8.0);
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_BloomContextMenuLayoutDelegate oldDelegate) => oldDelegate.anchor != anchor;
}
