// lib/src/primitives/toggle.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/controllable_value.dart';
import '../utils/extensions.dart';

enum BloomToggleVariant { defaultVariant, outline }

enum BloomToggleSize {
  defaultSize, // h-8 (32px)
  sm,          // h-7 (28px)
  lg,          // h-9 (36px)
}

/// Two-state toggle button matching shadcn/ui base-nova.
class BloomToggle extends StatefulWidget {
  final bool? checked;
  final bool defaultChecked;
  final ValueChanged<bool>? onPressed;
  final bool disabled;
  final BloomToggleVariant variant;
  final BloomToggleSize size;
  final Widget child;

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

class BloomToggleGroupItem<T> {
  final T value;
  final Widget label;
  const BloomToggleGroupItem({required this.value, required this.label});
}

/// Composable ToggleGroup supporting single and multiple selection matching shadcn base-nova.
class BloomToggleGroup<T> extends StatelessWidget {
  final List<BloomToggleGroupItem<T>>? items;
  final List<Widget>? children;
  final T? value;
  final List<T>? values;
  final ValueChanged<T>? onChanged;
  final ValueChanged<List<T>>? onMultipleChanged;
  final bool isMultiple;
  final bool disabled;
  final BloomToggleVariant variant;
  final BloomToggleSize size;
  final double spacing;
  final Axis orientation;

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
