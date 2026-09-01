// lib/src/primitives/button_group.dart
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';
import '../utils/bloom_pressable.dart';
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

/// Grouped button container matching shadcn/ui base-nova button-group.
class BloomButtonGroup<T> extends StatefulWidget {
  final List<BloomButtonGroupItem<T>>? items;
  final List<Widget>? children;
  final T? value;
  final T? defaultValue;
  final ValueChanged<T>? onChanged;
  final Axis orientation;
  final bool disabled;
  final bool joined;

  const BloomButtonGroup({
    super.key,
    this.items,
    this.children,
    this.value,
    this.defaultValue,
    this.onChanged,
    this.orientation = Axis.horizontal,
    this.disabled = false,
    this.joined = true,
  }) : assert(items != null || children != null, 'Provide items or children');

  @override
  State<BloomButtonGroup<T>> createState() => _BloomButtonGroupState<T>();
}

class _BloomButtonGroupState<T> extends State<BloomButtonGroup<T>> {
  late BloomControllableValue<T?> _state;

  @override
  void initState() {
    super.initState();
    _state = BloomControllableValue<T?>(
      controlledValue: widget.value,
      defaultValue: widget.defaultValue,
      onChanged: widget.onChanged != null ? (v) { if (v != null) widget.onChanged!(v); } : null,
    );
  }

  @override
  void didUpdateWidget(covariant BloomButtonGroup<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _state = BloomControllableValue<T?>(
        controlledValue: widget.value,
        defaultValue: widget.defaultValue,
        onChanged: widget.onChanged != null ? (v) { if (v != null) widget.onChanged!(v); } : null,
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

    // Slot-based children mode
    if (widget.children != null) {
      final kids = widget.children!;
      final isHoriz = widget.orientation == Axis.horizontal;

      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.bloomRadius.md),
        ),
        child: isHoriz
            ? Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: kids,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: kids,
              ),
      );
    }

    // Data items mode
    final items = widget.items!;
    final selected = _state.value;

    final children = List.generate(items.length, (index) {
      final item = items[index];
      final isFirst = index == 0;
      final isLast = index == items.length - 1;
      final isSelected = selected == item.value;

      BorderRadius itemRadius;
      if (!widget.joined) {
        itemRadius = BorderRadius.circular(context.bloomRadius.md);
      } else if (widget.orientation == Axis.horizontal) {
        itemRadius = BorderRadius.horizontal(
          left: isFirst ? Radius.circular(context.bloomRadius.md) : Radius.zero,
          right: isLast ? Radius.circular(context.bloomRadius.md) : Radius.zero,
        );
      } else {
        itemRadius = BorderRadius.vertical(
          top: isFirst ? Radius.circular(context.bloomRadius.md) : Radius.zero,
          bottom: isLast ? Radius.circular(context.bloomRadius.md) : Radius.zero,
        );
      }

      return BloomPressable(
        onTap: widget.disabled ? null : () => _select(item.value),
        borderRadius: itemRadius,
        child: AnimatedContainer(
          duration: BloomMotion.instant,
          height: 32, // h-8
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : colors.secondary,
            border: Border.all(color: colors.border),
            borderRadius: itemRadius,
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              color: isSelected ? colors.primaryForeground : colors.textPrimary,
              fontSize: 14,
              fontFamily: context.bloomTypography.sans,
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

/// Text addon slot in ButtonGroup
class BloomButtonGroupText extends StatelessWidget {
  final Widget child;

  const BloomButtonGroupText({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.bloomColors.surface0,
        border: Border.all(color: context.bloomColors.border),
        borderRadius: BorderRadius.circular(context.bloomRadius.md),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: context.bloomColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: context.bloomTypography.sans,
        ),
        child: child,
      ),
    );
  }
}

/// Separator line inside ButtonGroup
class BloomButtonGroupSeparator extends StatelessWidget {
  final Axis orientation;

  const BloomButtonGroupSeparator({
    super.key,
    this.orientation = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    if (orientation == Axis.vertical) {
      return Container(
        width: 1,
        height: 20,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        color: colors.border,
      );
    }
    return Container(
      height: 1,
      width: 20,
      margin: const EdgeInsets.symmetric(vertical: 2),
      color: colors.border,
    );
  }
}
