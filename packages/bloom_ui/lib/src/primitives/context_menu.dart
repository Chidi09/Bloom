// lib/src/primitives/context_menu.dart
import 'package:flutter/material.dart';
import 'dropdown_menu.dart';

class BloomContextMenu<T> extends StatelessWidget {
  final Widget child;
  final List<BloomDropdownMenuItem<T>> items;
  final ValueChanged<T> onSelected;

  const BloomContextMenu({
    super.key,
    required this.child,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) {
        final position = details.globalPosition;
        _showMenu(context, position);
      },
      onLongPressStart: (details) {
        final position = details.globalPosition;
        _showMenu(context, position);
      },
      child: child,
    );
  }

  void _showMenu(BuildContext context, Offset position) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    showMenu<T>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: items.map((item) {
        return PopupMenuItem<T>(
          value: item.value,
          child: Row(
            children: [
              if (item.icon != null) ...[
                item.icon!,
                const SizedBox(width: 8),
              ],
              Text(item.label),
            ],
          ),
        );
      }).toList(),
    ).then((val) {
      if (val != null) onSelected(val);
    });
  }
}
