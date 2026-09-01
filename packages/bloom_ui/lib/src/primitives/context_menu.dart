// lib/src/primitives/context_menu.dart
import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import '../utils/bloom_pressable.dart';
import '../utils/bloom_surface.dart';
import '../utils/extensions.dart';
import 'dropdown_menu.dart';

/// A contextual overlay menu triggered by secondary click (right-click) or long-press gestures.
///
/// Wraps a [child] widget and responds to desktop secondary mouse clicks (`onSecondaryTapDown`)
/// and mobile long-press gestures (`onLongPressStart`), displaying a floating menu styled
/// with Bloom design tokens at the cursor/pointer coordinates.
///
/// Example:
/// ```dart
/// BloomContextMenu(
///   items: [
///     BloomDropdownMenuItem(
///       label: 'Copy',
///       icon: BloomIcon(BloomIcons.copy),
///       shortcut: Text('Ctrl+C'),
///       onTap: () => print('Copy'),
///     ),
///     BloomDropdownMenuItem(
///       label: 'Delete',
///       icon: BloomIcon(BloomIcons.deleteOutline),
///       isDestructive: true,
///       onTap: () => print('Delete'),
///     ),
///   ],
///   child: Container(
///     padding: EdgeInsets.all(24),
///     child: Text('Right-click or long-press me'),
///   ),
/// );
/// ```
class BloomContextMenu extends StatefulWidget {
  /// The target widget that listens for right-click or long-press gestures.
  final Widget child;

  /// The list of items displayed inside the contextual menu.
  final List<BloomDropdownMenuItem> items;

  /// Width constraint of the contextual menu overlay. Defaults to `200`.
  final double width;

  /// Creates a [BloomContextMenu].
  ///
  /// * [child]: The target content that receives the gestures.
  /// * [items]: List of menu item definitions to display in the menu.
  /// * [width]: Width in logical pixels of the context menu popup (defaults to `200`).
  const BloomContextMenu({
    super.key,
    required this.child,
    required this.items,
    this.width = 200,
  });

  @override
  State<BloomContextMenu> createState() => _BloomContextMenuState();
}

class _BloomContextMenuState extends State<BloomContextMenu> {
  final MenuController _controller = MenuController();

  Widget _buildItem(BuildContext context, BloomDropdownMenuItem item) {
    final colors = context.bloomColors;
    final textCol = item.isDestructive
        ? colors.destructive
        : item.disabled
            ? colors.textTertiary
            : colors.textPrimary;

    return BloomPressable(
      enabled: !item.disabled,
      onTap: () {
        _controller.close();
        item.onTap?.call();
      },
      borderRadius: BorderRadius.circular(context.bloomRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            if (item.icon != null) ...[
              IconTheme(
                data: IconThemeData(color: textCol, size: 16),
                child: item.icon!,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  color: textCol,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  fontFamily: context.bloomTypography.sans,
                ),
              ),
            ),
            if (item.shortcut != null) item.shortcut!,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final radius = context.bloomRadius;

    return RawMenuAnchor(
      controller: _controller,
      overlayBuilder: (BuildContext context, RawMenuOverlayInfo info) {
        final base = info.anchorRect.topLeft;
        final pos = info.position != null ? base + info.position! : base;
        double left = pos.dx;
        double top = pos.dy;

        if (left + widget.width > info.overlaySize.width) {
          left = math.max(0.0, info.overlaySize.width - widget.width - 8);
        }
        if (top + (widget.items.length * 36) > info.overlaySize.height) {
          top = math.max(0.0, info.overlaySize.height - (widget.items.length * 36) - 8);
        }

        return TapRegion(
          groupId: info.tapRegionGroupId,
          onTapOutside: (PointerDownEvent event) {
            _controller.close();
          },
          child: CustomSingleChildLayout(
            delegate: _BloomContextMenuLayoutDelegate(position: Offset(left, top)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: widget.width,
                maxWidth: widget.width,
              ),
              child: BloomSurface(
                elevation: 8,
                borderRadius: BorderRadius.circular(radius.md),
                color: colors.surface1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius.md),
                    border: Border.all(color: colors.border),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final item in widget.items)
                        _buildItem(context, item),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (details) {
          _controller.open(position: details.localPosition);
        },
        onLongPressStart: (details) {
          _controller.open(position: details.localPosition);
        },
        child: widget.child,
      ),
    );
  }
}

class _BloomContextMenuLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset position;

  const _BloomContextMenuLayoutDelegate({required this.position});

  @override
  Offset getPositionForChild(Size size, Size childSize) => position;

  @override
  bool shouldRelayout(covariant _BloomContextMenuLayoutDelegate oldDelegate) =>
      position != oldDelegate.position;
}

