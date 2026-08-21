// lib/src/primitives/toggle.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/controllable_value.dart';
import '../utils/extensions.dart';

/// Visual style variants for [BloomToggle] and [BloomToggleGroup].
enum BloomToggleVariant {
  /// Default variant with transparent background when unselected and muted background when active.
  defaultVariant,

  /// Outline variant with a subtle border when unselected.
  outline,
}

/// Size options for [BloomToggle] and [BloomToggleGroup].
enum BloomToggleSize {
  /// Default height of 32px (h-8) with 14px font and 16px icon.
  defaultSize,

  /// Compact height of 28px (h-7) with 12.8px font and 14px icon.
  sm,

  /// Large height of 36px (h-9) with 14px font and 16px icon.
  lg,
}

/// A two-state toggle button matching shadcn/ui base-nova design specifications.
///
/// Supports controlled ([checked]) and uncontrolled ([defaultChecked]) modes,
/// outline and ghost styling variants, and multiple sizes.
///
/// ```dart
/// BloomToggle(
///   checked: isBold,
///   onPressed: (val) => setState(() => isBold = val),
///   child: const Icon(Icons.format_bold),
/// )
/// ```
class BloomToggle extends StatefulWidget {
  /// Whether the toggle is currently active (controlled mode).
  final bool? checked;

  /// The initial active state when operating in uncontrolled mode.
  ///
  /// Defaults to `false`.
  final bool defaultChecked;

  /// Callback invoked when the toggle is clicked.
  final ValueChanged<bool>? onPressed;

  /// Whether the toggle is disabled and non-interactive.
  final bool disabled;

  /// The visual style variant of the toggle.
  ///
  /// Defaults to [BloomToggleVariant.defaultVariant].
  final BloomToggleVariant variant;

  /// The size of the toggle.
  ///
  /// Defaults to [BloomToggleSize.defaultSize].
  final BloomToggleSize size;

  /// The widget content rendered inside the toggle (typically an icon or text label).
  final Widget child;

  /// Creates a [BloomToggle].
  const BloomToggle({
    super.key,
    this.checked,
    this.defaultChecked = false,
    this.onPressed,
    this.disabled = false,
    this.variant = BloomToggleVariant.defaultVariant,
    this.size = BloomToggleSize.defaultSize,
    required this.child,
  });

  @override
  State<BloomToggle> createState() => _BloomToggleState();
}

class _BloomToggleState extends State<BloomToggle> {
  late BloomControllableValue<bool> _state;

  @override
  void initState() {
    super.initState();
    _state = BloomControllableValue<bool>(
      controlledValue: widget.checked,
      defaultValue: widget.defaultChecked,
      onChanged: widget.onPressed,
    );
  }

  @override
  void didUpdateWidget(covariant BloomToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.checked != oldWidget.checked) {
      _state = BloomControllableValue<bool>(
        controlledValue: widget.checked,
        defaultValue: widget.defaultChecked,
        onChanged: widget.onPressed,
      );
    }
  }

  void _toggle() {
    if (widget.disabled) return;
    setState(() => _state.update(!_state.value));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final isSelected = _state.value;
    final dims = _resolveDimensions(widget.size);

    Color bg;
    if (isSelected) {
      bg = colors.surface0; // bg-muted
    } else {
      bg = Colors.transparent;
    }

    Color textCol = isSelected ? colors.textPrimary : colors.textSecondary;
    Color borderCol = widget.variant == BloomToggleVariant.outline
        ? colors.border
        : Colors.transparent;

    return Semantics(
      toggled: isSelected,
      enabled: !widget.disabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.disabled ? null : _toggle,
          borderRadius: BorderRadius.circular(context.bloomRadius.md),
          child: AnimatedContainer(
            duration: BloomMotion.instant,
            height: dims.height,
            constraints: BoxConstraints(minWidth: dims.height),
            padding: dims.padding,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(context.bloomRadius.md),
              border: borderCol != Colors.transparent ? Border.all(color: borderCol) : null,
            ),
            child: IconTheme(
              data: IconThemeData(color: textCol, size: dims.iconSize),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: textCol,
                  fontSize: dims.fontSize,
                  fontWeight: FontWeight.w500,
                  fontFamily: context.bloomTypography.sans,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  _ToggleDimensions _resolveDimensions(BloomToggleSize size) {
    switch (size) {
      case BloomToggleSize.sm:
        return const _ToggleDimensions(
          height: 28,
          padding: EdgeInsets.symmetric(horizontal: 10),
          fontSize: 12.8,
          iconSize: 14,
        );
      case BloomToggleSize.defaultSize:
        return const _ToggleDimensions(
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: 10),
          fontSize: 14,
          iconSize: 16,
        );
      case BloomToggleSize.lg:
        return const _ToggleDimensions(
          height: 36,
          padding: EdgeInsets.symmetric(horizontal: 10),
          fontSize: 14,
          iconSize: 16,
        );
    }
  }
}

class _ToggleDimensions {
  final double height;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final double iconSize;
  const _ToggleDimensions({
    required this.height,
    required this.padding,
    required this.fontSize,
    required this.iconSize,
  });
}

/// A data model representing an item in a [BloomToggleGroup].
class BloomToggleGroupItem<T> {
  /// The value associated with this toggle option.
  final T value;

  /// The widget label or icon displayed inside the toggle button.
  final Widget label;

  /// Creates a [BloomToggleGroupItem].
  const BloomToggleGroupItem({required this.value, required this.label});
}

/// A composable toggle button group matching shadcn base-nova design specifications.
///
/// Supports single selection mode ([value], [onChanged]) and multiple selection mode
/// ([values], [onMultipleChanged], [isMultiple] set to `true`).
///
/// ```dart
/// // Single selection
/// BloomToggleGroup<String>(
///   value: selectedAlign,
///   items: const [
///     BloomToggleGroupItem(value: 'left', label: Icon(Icons.format_align_left)),
///     BloomToggleGroupItem(value: 'center', label: Icon(Icons.format_align_center)),
///     BloomToggleGroupItem(value: 'right', label: Icon(Icons.format_align_right)),
///   ],
///   onChanged: (val) => setState(() => selectedAlign = val),
/// )
///
/// // Multiple selection
/// BloomToggleGroup<String>(
///   isMultiple: true,
///   values: activeFormats,
///   items: const [
///     BloomToggleGroupItem(value: 'bold', label: Icon(Icons.format_bold)),
///     BloomToggleGroupItem(value: 'italic', label: Icon(Icons.format_italic)),
///     BloomToggleGroupItem(value: 'underline', label: Icon(Icons.format_underlined)),
///   ],
///   onMultipleChanged: (vals) => setState(() => activeFormats = vals),
/// )
/// ```
class BloomToggleGroup<T> extends StatelessWidget {
  /// Structured list of toggle items. Mutually exclusive with [children].
  final List<BloomToggleGroupItem<T>>? items;

  /// Custom list of child widgets. Mutually exclusive with [items].
  final List<Widget>? children;

  /// The currently selected value for single-selection mode.
  final T? value;

  /// The currently selected values for multiple-selection mode.
  final List<T>? values;

  /// Callback invoked when selection changes in single-selection mode.
  final ValueChanged<T>? onChanged;

  /// Callback invoked when selection changes in multiple-selection mode.
  final ValueChanged<List<T>>? onMultipleChanged;

  /// Whether multiple toggle items can be simultaneously selected.
  ///
  /// Defaults to `false`.
  final bool isMultiple;

  /// Whether the entire toggle group is disabled.
  final bool disabled;

  /// The visual variant for items in this toggle group.
  final BloomToggleVariant variant;

  /// The size variant for items in this toggle group.
  final BloomToggleSize size;

  /// Spacing between toggle items.
  ///
  /// Defaults to `2.0`.
  final double spacing;

  /// The layout orientation of the toggle group.
  ///
  /// Defaults to [Axis.horizontal].
  final Axis orientation;

  /// Creates a [BloomToggleGroup].
  const BloomToggleGroup({
    super.key,
    this.items,
    this.children,
    this.value,
    this.values,
    this.onChanged,
    this.onMultipleChanged,
    this.isMultiple = false,
    this.disabled = false,
    this.variant = BloomToggleVariant.defaultVariant,
    this.size = BloomToggleSize.defaultSize,
    this.spacing = 2,
    this.orientation = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    if (children != null) {
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        direction: orientation,
        children: children!,
      );
    }

    final itemList = items!;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      direction: orientation,
      children: itemList.map((item) {
        final isSelected = isMultiple
            ? (values?.contains(item.value) ?? false)
            : (value == item.value);

        return BloomToggle(
          checked: isSelected,
          disabled: disabled,
          variant: variant,
          size: size,
          onPressed: (_) {
            if (isMultiple) {
              final next = List<T>.from(values ?? []);
              if (next.contains(item.value)) {
                next.remove(item.value);
              } else {
                next.add(item.value);
              }
              onMultipleChanged?.call(next);
            } else {
              onChanged?.call(item.value);
            }
          },
          child: item.label,
        );
      }).toList(),
    );
  }
}
