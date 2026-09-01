// lib/src/primitives/select.dart
import 'package:flutter/widgets.dart';

import '../icons/bloom_icon.dart';
import '../icons/bloom_icons.dart';
import '../theme/tokens.dart';
import '../utils/bloom_pressable.dart';
import '../utils/bloom_surface.dart';
import '../utils/extensions.dart';
import 'input.dart';

/// An item entry for [BloomSelect] representing a selectable option.
///
/// Contains the underlying [value], user-facing [label], and optional leading [icon].
class BloomSelectItem<T> {
  /// The value associated with this item.
  final T value;

  /// The human-readable text label displayed in the dropdown menu.
  final String label;

  /// An optional leading icon displayed beside the label.
  final Widget? icon;

  /// Creates a [BloomSelectItem].
  const BloomSelectItem({
    required this.value,
    required this.label,
    this.icon,
  });
}

/// A dropdown select input field primitive styled according to Bloom design tokens.
///
/// ```dart
/// BloomSelect<String>(
///   value: selectedRole,
///   hintText: 'Select a role',
///   items: const [
///     BloomSelectItem(value: 'admin', label: 'Admin'),
///     BloomSelectItem(value: 'user', label: 'User'),
///   ],
///   onChanged: (val) => setState(() => selectedRole = val),
/// )
/// ```
class BloomSelect<T> extends StatefulWidget {
  /// The currently selected value, matching one of the [items]' values.
  final T? value;

  /// The list of selectable items displayed in the dropdown menu.
  final List<BloomSelectItem<T>> items;

  /// Callback invoked when the user selects an option.
  final ValueChanged<T?>? onChanged;

  /// Optional placeholder text shown when no item is selected.
  final String? hintText;

  /// Optional label text displayed as the input decoration label.
  final String? labelText;

  /// Whether the select input is disabled and non-interactive.
  final bool disabled;

  /// Creates a [BloomSelect].
  const BloomSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hintText,
    this.labelText,
    this.disabled = false,
  });

  @override
  State<BloomSelect<T>> createState() => _BloomSelectState<T>();
}

class _BloomSelectState<T> extends State<BloomSelect<T>> {
  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _portalController = OverlayPortalController();

  void _toggleOverlay() {
    _portalController.toggle();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    BloomSelectItem<T>? selectedItem;
    for (final item in widget.items) {
      if (item.value == widget.value) {
        selectedItem = item;
        break;
      }
    }

    final isDark = colors.brightness == Brightness.dark;
    final decoration = bloomInputDecoration(
      context,
      hintText: widget.hintText,
      labelText: widget.labelText,
      filled: isDark,
      disabled: widget.disabled,
    );

    final Widget selectBox = OverlayPortal(
      controller: _portalController,
      overlayChildBuilder: (context) => _SelectOverlay<T>(
        layerLink: _layerLink,
        items: widget.items,
        selectedValue: widget.value,
        onSelected: (item) {
          widget.onChanged?.call(item.value);
          _portalController.hide();
        },
        onDismiss: _portalController.hide,
      ),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Semantics(
          button: true,
          enabled: !widget.disabled,
          child: GestureDetector(
            onTap: widget.disabled ? null : _toggleOverlay,
            child: Container(
              height: 36,
              decoration: decoration,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  if (selectedItem?.icon != null) ...[
                    selectedItem!.icon!,
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      selectedItem?.label ?? widget.hintText ?? '',
                      style: TextStyle(
                        color: selectedItem != null ? colors.textPrimary : colors.textTertiary,
                        fontSize: 14,
                        fontFamily: context.bloomTypography.sans,
                      ),
                    ),
                  ),
                  BloomIcon(BloomIcons.keyboardArrowDown, color: colors.textSecondary, size: 20),
                ],
              ),
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
              fontSize: 14,
              fontFamily: context.bloomTypography.sans,
            ),
          ),
          const SizedBox(height: 6),
          selectBox,
        ],
      );
    }

    return selectBox;
  }
}

class _SelectOverlay<T> extends StatelessWidget {
  final LayerLink layerLink;
  final List<BloomSelectItem<T>> items;
  final T? selectedValue;
  final ValueChanged<BloomSelectItem<T>> onSelected;
  final VoidCallback onDismiss;

  const _SelectOverlay({
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
                    child: Row(
                      children: [
                        if (item.icon != null) ...[
                          item.icon!,
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: isSelected ? colors.primary : colors.textPrimary,
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              fontFamily: context.bloomTypography.sans,
                            ),
                          ),
                        ),
                      ],
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
