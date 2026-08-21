// lib/src/primitives/combobox.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/extensions.dart';
import 'input.dart';

/// An item entry for [BloomCombobox].
///
/// Contains the underlying [value], the searchable [label], and an optional leading [icon].
class BloomComboboxItem<T> {
  /// The value associated with this item.
  final T value;

  /// The searchable and display text label for this item.
  final String label;

  /// An optional leading icon widget displayed beside the label.
  final Widget? icon;

  /// Creates a [BloomComboboxItem].
  const BloomComboboxItem({
    required this.value,
    required this.label,
    this.icon,
  });
}

/// A searchable combobox (autocomplete dropdown) primitive with floating overlay menu.
///
/// Opens a dropdown popup containing a search filter input and filtered list of selectable items.
///
/// ```dart
/// BloomCombobox<String>(
///   value: selectedFramework,
///   items: const [
///     BloomComboboxItem(value: 'flutter', label: 'Flutter'),
///     BloomComboboxItem(value: 'react', label: 'React'),
///     BloomComboboxItem(value: 'vue', label: 'Vue'),
///   ],
///   searchPlaceholder: 'Search frameworks...',
///   onChanged: (val) => setState(() => selectedFramework = val),
/// )
/// ```
class BloomCombobox<T extends Object> extends StatefulWidget {
  /// The currently selected value matching an item in [items].
  final T? value;

  /// The list of items available for filtering and selection.
  final List<BloomComboboxItem<T>> items;

  /// Callback invoked when an item is selected from the menu.
  final ValueChanged<T?>? onChanged;

  /// Optional hint text displayed when no item is selected.
  final String? hintText;

  /// Optional label text.
  final String? labelText;

  /// Placeholder text displayed inside the search filter field.
  ///
  /// Defaults to `'Search...'`.
  final String searchPlaceholder;

  /// Whether the combobox is disabled and non-interactive.
  final bool disabled;

  /// The maximum height of the floating dropdown menu popup.
  ///
  /// Defaults to `280.0`.
  final double menuMaxHeight;

  /// Creates a [BloomCombobox].
  const BloomCombobox({
    super.key,
    this.value,
    required this.items,
    this.onChanged,
    this.hintText,
    this.labelText,
    this.searchPlaceholder = 'Search...',
    this.disabled = false,
    this.menuMaxHeight = 280,
  });

  @override
  State<BloomCombobox<T>> createState() => _BloomComboboxState<T>();
}

class _BloomComboboxState<T extends Object> extends State<BloomCombobox<T>> {
  final _searchController = TextEditingController();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  List<BloomComboboxItem<T>> get _filteredItems {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return widget.items;
    return widget.items.where((i) => i.label.toLowerCase().contains(query)).toList();
  }

  void _toggleOverlay() {
    if (_isOpen) {
      _closeOverlay();
    } else {
      _openOverlay();
    }
  }

  void _openOverlay() {
    _searchController.clear();
    _overlayEntry = OverlayEntry(
      builder: (context) => _ComboboxPopup<T>(
        layerLink: _layerLink,
        filteredItems: _filteredItems,
        searchController: _searchController,
        searchPlaceholder: widget.searchPlaceholder,
        menuMaxHeight: widget.menuMaxHeight,
        onSelected: (item) {
          widget.onChanged?.call(item.value);
          _closeOverlay();
        },
        onSearchChanged: () => _overlayEntry?.markNeedsBuild(),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isOpen = false);
  }

  @override
  void dispose() {
    _closeOverlay();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final selectedItem = widget.items.firstWhere(
      (i) => i.value == widget.value,
      orElse: () => widget.items.first,
    );

    return CompositedTransformTarget(
      link: _layerLink,
      child: Semantics(
        button: true,
        enabled: !widget.disabled,
        child: GestureDetector(
          onTap: widget.disabled ? null : _toggleOverlay,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: colors.surface2,
              borderRadius: BorderRadius.circular(context.bloomRadius.md),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedItem.label,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontFamily: context.bloomTypography.sans,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: colors.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComboboxPopup<T extends Object> extends StatefulWidget {
  final LayerLink layerLink;
  final List<BloomComboboxItem<T>> filteredItems;
  final TextEditingController searchController;
  final String searchPlaceholder;
  final double menuMaxHeight;
  final ValueChanged<BloomComboboxItem<T>> onSelected;
  final VoidCallback onSearchChanged;

  const _ComboboxPopup({
    required this.layerLink,
    required this.filteredItems,
    required this.searchController,
    required this.searchPlaceholder,
    required this.menuMaxHeight,
    required this.onSelected,
    required this.onSearchChanged,
  });

  @override
  State<_ComboboxPopup<T>> createState() => _ComboboxPopupState<T>();
}

class _ComboboxPopupState<T extends Object> extends State<_ComboboxPopup<T>> {
  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(widget.onSearchChanged);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(widget.onSearchChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return CompositedTransformFollower(
      link: widget.layerLink,
      targetAnchor: Alignment.bottomLeft,
      followerAnchor: Alignment.topLeft,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            minWidth: 200,
            maxHeight: widget.menuMaxHeight,
          ),
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: colors.surface1,
            borderRadius: BorderRadius.circular(context.bloomRadius.md),
            border: Border.all(color: colors.border),
            boxShadow: const [BloomShadows.s2],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: BloomInput(
                  controller: widget.searchController,
                  hintText: widget.searchPlaceholder,
                  prefixIcon: Icon(Icons.search, color: colors.textTertiary, size: 16),
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: widget.filteredItems.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No results',
                          style: TextStyle(
                            color: colors.textTertiary,
                            fontSize: 14,
                            fontFamily: context.bloomTypography.sans,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        shrinkWrap: true,
                        itemCount: widget.filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = widget.filteredItems[index];
                          return _ComboboxItemRow<T>(
                            item: item,
                            onTap: () => widget.onSelected(item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComboboxItemRow<T extends Object> extends StatelessWidget {
  final BloomComboboxItem<T> item;
  final VoidCallback onTap;

  const _ComboboxItemRow({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
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
                  color: colors.textPrimary,
                  fontSize: 14,
                  fontFamily: context.bloomTypography.sans,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
