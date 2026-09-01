// lib/src/primitives/native_select.dart
import 'package:flutter/widgets.dart';

import '../icons/bloom_icon.dart';
import '../icons/bloom_icons.dart';
import '../theme/tokens.dart';
import '../utils/bloom_pressable.dart';
import '../utils/bloom_surface.dart';
import '../utils/extensions.dart';

/// An item entry for [BloomNativeSelect].
///
/// Holds the underlying [value] and user-facing [label] text.
class BloomNativeSelectItem<T> {
  /// The value associated with this item.
  final T value;

  /// The text label displayed for this item in the select menu.
  final String label;

  /// Creates a [BloomNativeSelectItem].
  const BloomNativeSelectItem({
    required this.value,
    required this.label,
  });
}

/// A compact native styled dropdown select button primitive.
///
/// Renders a framed container with subtle border, surface background, and an arrow indicator.
///
/// ```dart
/// BloomNativeSelect<String>(
///   value: selectedCountry,
///   hintText: 'Select country',
///   items: const [
///     BloomNativeSelectItem(value: 'us', label: 'United States'),
///     BloomNativeSelectItem(value: 'ca', label: 'Canada'),
///   ],
///   onChanged: (val) => setState(() => selectedCountry = val),
/// )
/// ```
class BloomNativeSelect<T> extends StatefulWidget {
  /// The currently selected value, matching one of the [items]' values.
  final T? value;

  /// The list of selectable items.
  final List<BloomNativeSelectItem<T>> items;

  /// Callback invoked when an item is selected.
  final ValueChanged<T?>? onChanged;

  /// Optional placeholder text displayed when [value] is null.
  final String? hintText;

  /// Optional label text descriptor.
  final String? labelText;

  /// Whether the select is disabled and non-interactive.
  final bool disabled;

  /// Creates a [BloomNativeSelect].
  const BloomNativeSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hintText,
    this.labelText,
    this.disabled = false,
  });

  @override
  State<BloomNativeSelect<T>> createState() => _BloomNativeSelectState<T>();
}

class _BloomNativeSelectState<T> extends State<BloomNativeSelect<T>> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _toggleOverlay() {
    if (_isOpen) {
      _closeOverlay();
    } else {
      _openOverlay();
    }
  }

  void _openOverlay() {
    _overlayEntry = OverlayEntry(
      builder: (context) => _NativeSelectOverlay<T>(
        layerLink: _layerLink,
        items: widget.items,
        selectedValue: widget.value,
        onSelected: (item) {
          widget.onChanged?.call(item.value);
          _closeOverlay();
        },
        onDismiss: _closeOverlay,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() => _isOpen = false);
    }
  }

  @override
  void dispose() {
    _closeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    BloomNativeSelectItem<T>? selectedItem;
    for (final item in widget.items) {
      if (item.value == widget.value) {
        selectedItem = item;
        break;
      }
    }

    final displayText = selectedItem?.label ?? widget.hintText ?? '';
    final isPlaceholder = selectedItem == null;

    final selectButton = CompositedTransformTarget(
      link: _layerLink,
      child: Semantics(
        button: true,
        enabled: !widget.disabled,
        child: GestureDetector(
          onTap: widget.disabled ? null : _toggleOverlay,
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: BorderRadius.circular(context.bloomRadius.md),
              border: Border.all(color: colors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      color: isPlaceholder ? colors.textTertiary : colors.textPrimary,
                      fontSize: 14,
                      fontFamily: context.bloomTypography.sans,
                    ),
                  ),
                ),
                BloomIcon(BloomIcons.arrowDropDown, color: colors.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.labelText != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.labelText!,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              fontFamily: context.bloomTypography.sans,
            ),
          ),
          const SizedBox(height: 6),
          selectButton,
        ],
      );
    }

    return selectButton;
  }
}

class _NativeSelectOverlay<T> extends StatelessWidget {
  final LayerLink layerLink;
  final List<BloomNativeSelectItem<T>> items;
  final T? selectedValue;
  final ValueChanged<BloomNativeSelectItem<T>> onSelected;
  final VoidCallback onDismiss;

  const _NativeSelectOverlay({
    required this.layerLink,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: layerLink,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          child: BloomSurface(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(context.bloomRadius.md),
            color: colors.surface1,
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 200,
                maxHeight: 280,
              ),
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: colors.surface1,
                borderRadius: BorderRadius.circular(context.bloomRadius.md),
                border: Border.all(color: colors.border),
                boxShadow: const [BloomShadows.s2],
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = item.value == selectedValue;
                  return BloomPressable(
                    onTap: () => onSelected(item),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? colors.primary : colors.textPrimary,
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontFamily: context.bloomTypography.sans,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
