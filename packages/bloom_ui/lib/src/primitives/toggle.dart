// lib/src/primitives/toggle.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/controllable_value.dart';
import '../utils/extensions.dart';

class BloomToggle extends StatefulWidget {
  final bool? checked;
  final bool defaultChecked;
  final ValueChanged<bool>? onPressed;
  final bool disabled;
  final Widget child;

  const BloomToggle({
    super.key,
    this.checked,
    this.defaultChecked = false,
    this.onPressed,
    this.disabled = false,
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

    return Semantics(
      button: true,
      enabled: isInteractive,
      toggled: isChecked,
      child: GestureDetector(
        onTap: _toggle,
        child: AnimatedContainer(
          duration: BloomMotion.instant,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isChecked ? colors.primary : colors.surface1,
            border: Border.all(
              color: isChecked ? colors.primary : colors.border,
            ),
            borderRadius: BorderRadius.circular(theme.radius.md),
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              color: isChecked ? colors.primaryForeground : colors.textPrimary,
              fontSize: 14,
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

class BloomToggleGroupItem<T> {
  final T value;
  final Widget label;

  const BloomToggleGroupItem({
    required this.value,
    required this.label,
  });
}

class BloomToggleGroup<T> extends StatefulWidget {
  final List<BloomToggleGroupItem<T>> items;
  final T? value;
  final T defaultValue;
  final ValueChanged<T>? onChanged;
  final bool disabled;

  const BloomToggleGroup({
    super.key,
    required this.items,
    this.value,
    required this.defaultValue,
    this.onChanged,
    this.disabled = false,
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
    final theme = context.bloomTheme;
    final colors = theme.colors;

    return Semantics(
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: widget.items.map((item) {
          final selected = _state.value == item.value;

          return GestureDetector(
            onTap: widget.disabled ? null : () => _select(item.value),
            child: AnimatedContainer(
              duration: BloomMotion.instant,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? colors.primary : colors.surface1,
                border: Border.all(
                  color: selected ? colors.primary : colors.border,
                ),
                borderRadius: BorderRadius.circular(theme.radius.md),
              ),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: selected ? colors.primaryForeground : colors.textPrimary,
                  fontSize: 14,
                  fontFamily: theme.typography.sans,
                  fontWeight: FontWeight.w500,
                ),
                child: item.label,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
