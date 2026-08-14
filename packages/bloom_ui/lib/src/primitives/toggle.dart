// lib/src/primitives/toggle.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/controllable_value.dart';
import '../utils/extensions.dart';

enum BloomToggleVariant { defaultVariant, outline }

enum BloomToggleSize { defaultSize, sm, lg }

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
    final next = !_state.value;
    setState(() => _state.update(next));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.bloomTheme;
    final colors = theme.colors;
    final isChecked = _state.value;
    final isInteractive = !widget.disabled;
    final dims = _resolveSize(widget.size);

    Color bg;
    Color fg;
    Color border;
    if (widget.variant == BloomToggleVariant.outline) {
      bg = isChecked ? colors.muted : Colors.transparent;
      fg = colors.textPrimary;
      border = colors.buttonBorder;
    } else {
      bg = isChecked ? colors.muted : Colors.transparent;
      fg = colors.textPrimary;
      border = Colors.transparent;
    }

    return Semantics(
      button: true,
      enabled: isInteractive,
      toggled: isChecked,
        child: GestureDetector(
          onTap: isInteractive ? _toggle : null,
          child: AnimatedContainer(
            duration: BloomMotion.instant,
            height: dims.height,
            constraints: BoxConstraints(minWidth: dims.minWidth),
            padding: dims.padding,
          decoration: BoxDecoration(
            color: bg,
            border: border == Colors.transparent ? null : Border.all(color: border),
            borderRadius: BorderRadius.circular(theme.radius.md),
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              color: fg,
              fontSize: dims.fontSize,
              fontFamily: theme.typography.sans,
              fontWeight: FontWeight.w500,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

_ToggleDims _resolveSize(BloomToggleSize size) {
  switch (size) {
    case BloomToggleSize.sm:
      return const _ToggleDims(height: 28, minWidth: 28, padding: EdgeInsets.symmetric(horizontal: 10), fontSize: 12.8);
    case BloomToggleSize.defaultSize:
      return const _ToggleDims(height: 32, minWidth: 32, padding: EdgeInsets.symmetric(horizontal: 10), fontSize: 14);
    case BloomToggleSize.lg:
      return const _ToggleDims(height: 36, minWidth: 36, padding: EdgeInsets.symmetric(horizontal: 10), fontSize: 14);
  }
}

class _ToggleDims {
  final double height;
  final double minWidth;
  final EdgeInsets padding;
  final double fontSize;
  const _ToggleDims({required this.height, required this.minWidth, required this.padding, required this.fontSize});
}

class BloomToggleGroupItem<T> {
  final T value;
  final Widget label;

  const BloomToggleGroupItem({required this.value, required this.label});
}

class BloomToggleGroup<T> extends StatefulWidget {
  final List<BloomToggleGroupItem<T>> items;
  final T? value;
  final T defaultValue;
  final ValueChanged<T>? onChanged;
  final bool disabled;
  final BloomToggleVariant variant;
  final int spacing;

  const BloomToggleGroup({
    super.key,
    required this.items,
    this.value,
    required this.defaultValue,
    this.onChanged,
    this.disabled = false,
    this.variant = BloomToggleVariant.defaultVariant,
    this.spacing = 2,
  });

  @override
  State<BloomToggleGroup<T>> createState() => _BloomToggleGroupState<T>();
}

class _BloomToggleGroupState<T> extends State<BloomToggleGroup<T>> {
  late BloomControllableValue<T> _state;

  @override
  void initState() {
    super.initState();
    _state = BloomControllableValue<T>(
      controlledValue: widget.value,
      defaultValue: widget.defaultValue,
      onChanged: widget.onChanged,
    );
  }

  @override
  void didUpdateWidget(covariant BloomToggleGroup<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _state = BloomControllableValue<T>(
        controlledValue: widget.value,
        defaultValue: widget.defaultValue,
        onChanged: widget.onChanged,
      );
    }
  }

  void _select(T value) {
    if (widget.disabled) return;
    setState(() => _state.update(value));
  }

  @override
  Widget build(BuildContext context) {
    final selected = _state.value;

    return Semantics(
      child: Wrap(
        spacing: widget.spacing.toDouble(),
        runSpacing: widget.spacing.toDouble(),
        children: widget.items.map((item) {
          return BloomToggle(
            checked: selected == item.value,
            onPressed: widget.disabled ? null : (_) => _select(item.value),
            variant: widget.variant,
            child: item.label,
          );
        }).toList(),
      ),
    );
  }
}
