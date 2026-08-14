// lib/src/primitives/menubar.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';

class BloomMenubarMenuItem {
  final String label;
  final Widget? icon;
  final VoidCallback? onSelected;
  final bool isDestructive;
  final bool isSeparator;

  const BloomMenubarMenuItem({
    required this.label,
    this.icon,
    this.onSelected,
    this.isDestructive = false,
    this.isSeparator = false,
  });

  const BloomMenubarMenuItem.separator()
      : label = '',
        icon = null,
        onSelected = null,
        isDestructive = false,
        isSeparator = true;
}

class BloomMenubarItem {
  final String label;
  final List<BloomMenubarMenuItem> items;

  const BloomMenubarItem({
    required this.label,
    required this.items,
  });
}

class BloomMenubar extends StatefulWidget {
  final List<BloomMenubarItem> items;

  const BloomMenubar({
    super.key,
    required this.items,
  });

  @override
  State<BloomMenubar> createState() => _BloomMenubarState();
}

class _BloomMenubarState extends State<BloomMenubar> {
  int? _openIndex;

  void _toggleMenu(int index) {
    setState(() {
      _openIndex = _openIndex == index ? null : index;
    });
  }

  void _closeAll() {
    setState(() => _openIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Semantics(
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: colors.surface1,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(context.bloomRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.items.length, (index) {
            final item = widget.items[index];
            final isOpen = _openIndex == index;

            return _BloomMenubarLabel(
              label: item.label,
              isOpen: isOpen,
              onTap: () => _toggleMenu(index),
              child: isOpen
                  ? _BloomMenubarDropdown(
                      items: item.items,
                      onClose: _closeAll,
                    )
                  : null,
            );
          }),
        ),
      ),
    );
  }
}

class _BloomMenubarLabel extends StatefulWidget {
  final String label;
  final bool isOpen;
  final VoidCallback onTap;
  final Widget? child;

  const _BloomMenubarLabel({
    required this.label,
    required this.isOpen,
    required this.onTap,
    this.child,
  });

  @override
  State<_BloomMenubarLabel> createState() => _BloomMenubarLabelState();
}

class _BloomMenubarLabelState extends State<_BloomMenubarLabel> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void didUpdateWidget(_BloomMenubarLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && _overlayEntry == null) {
      _insertOverlay();
    } else if (!widget.isOpen && _overlayEntry != null) {
      _removeOverlay();
    }
  }

  void _insertOverlay() {
    _overlayEntry = OverlayEntry(
      builder: (_) => CompositedTransformFollower(
        link: _layerLink,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        child: widget.child!,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: widget.isOpen ? colors.secondary : Colors.transparent,
            child: Text(
              widget.label,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                fontFamily: context.bloomTypography.sans,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BloomMenubarDropdown extends StatelessWidget {
  final List<BloomMenubarMenuItem> items;
  final VoidCallback onClose;

  const _BloomMenubarDropdown({
    required this.items,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(minWidth: 180),
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: colors.surface1,
          borderRadius: BorderRadius.circular(context.bloomRadius.md),
          border: Border.all(color: colors.border),
          boxShadow: const [BloomShadows.s2],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items.map((item) {
            if (item.isSeparator) {
              return Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: colors.border,
              );
            }
            return Semantics(
              button: true,
              child: InkWell(
                onTap: () {
                  item.onSelected?.call();
                  onClose();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      if (item.icon != null) ...[
                        item.icon!,
                        const SizedBox(width: 8),
                      ],
                      Text(
                        item.label,
                        style: TextStyle(
                          color: item.isDestructive ? colors.error : colors.textPrimary,
                          fontSize: 14,
                          fontFamily: context.bloomTypography.sans,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
