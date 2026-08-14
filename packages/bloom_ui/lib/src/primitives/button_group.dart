// lib/src/primitives/button_group.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/controllable_value.dart';
import '../utils/extensions.dart';

class BloomButtonGroupItem<T> {
  final T value;
  final Widget label;

  const BloomButtonGroupItem({
    required this.value,
    required this.label,
  });
}

class BloomButtonGroup<T> extends StatefulWidget {
  final List<BloomButtonGroupItem<T>> items;
  final T? value;
  final T defaultValue;
  final ValueChanged<T>? onChanged;
  final Axis orientation;
  final bool disabled;
  final bool joined;

  const BloomButtonGroup({
    super.key,
    required this.items,
    this.value,
    required this.defaultValue,
    this.onChanged,
    this.orientation = Axis.horizontal,
    this.disabled = false,
    this.joined = true,
  });

  @override
  State<BloomButtonGroup<T>> createState() => _BloomButtonGroupState<T>();
}

class _BloomButtonGroupState<T> extends State<BloomButtonGroup<T>> {
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
  void didUpdateWidget(covariant BloomButtonGroup<T> oldWidget) {
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
    final colors = context.bloomColors;
    final theme = context.bloomTheme;
    final radius = theme.radius;

    final children = List.generate(widget.items.length, (i) {
      final item = widget.items[i];
      final selected = _state.value == item.value;
      final isFirst = i == 0;
      final isLast = i == widget.items.length - 1;

      BorderRadius itemRadius = BorderRadius.zero;
      if (!widget.joined) {
        itemRadius = BorderRadius.circular(radius.md);
      } else if (isFirst && isLast) {
        itemRadius = BorderRadius.circular(radius.md);
      } else if (widget.orientation == Axis.horizontal) {
        if (isFirst) {
          itemRadius = BorderRadius.only(
            topLeft: Radius.circular(radius.md),
            bottomLeft: Radius.circular(radius.md),
          );
        } else if (isLast) {
          itemRadius = BorderRadius.only(
            topRight: Radius.circular(radius.md),
            bottomRight: Radius.circular(radius.md),
          );
        }
      } else {
        if (isFirst) {
          itemRadius = BorderRadius.only(
            topLeft: Radius.circular(radius.md),
            topRight: Radius.circular(radius.md),
          );
        } else if (isLast) {
          itemRadius = BorderRadius.only(
            bottomLeft: Radius.circular(radius.md),
            bottomRight: Radius.circular(radius.md),
          );
        }
      }

      return GestureDetector(
        onTap: widget.disabled ? null : () => _select(item.value),
        child: AnimatedContainer(
          duration: BloomMotion.instant,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.secondary,
            border: Border.all(color: colors.border),
            borderRadius: itemRadius,
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
    });

    if (widget.orientation == Axis.vertical) {
      return IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

class BloomButtonGroupText extends StatelessWidget {
  final Widget child;

  const BloomButtonGroupText({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: DefaultTextStyle(
        style: TextStyle(
          color: context.bloomColors.textSecondary,
          fontSize: 14,
          fontFamily: context.bloomTypography.sans,
        ),
        child: child,
      ),
    );
  }
}
