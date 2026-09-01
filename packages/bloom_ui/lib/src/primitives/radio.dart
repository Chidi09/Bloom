// lib/src/primitives/radio.dart
import 'package:flutter/widgets.dart';
import '../theme/tokens.dart';
import '../utils/bloom_pressable.dart';
import '../utils/controllable_value.dart';
import '../utils/extensions.dart';

/// Single radio item matching shadcn base-nova 16x16px circle.
class BloomRadio<T> extends StatelessWidget {
  final T value;
  final T? groupValue;
  final ValueChanged<T>? onChanged;
  final bool disabled;
  final Widget? label;

  const BloomRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.disabled = false,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final isSelected = value == groupValue;

    final circle = AnimatedContainer(
      duration: BloomMotion.instant,
      width: 16, // size-4
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? colors.primary : BloomColors.transparent,
        border: Border.all(
          color: isSelected ? colors.primary : colors.border,
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: isSelected
          ? Container(
              width: 6, // 6-8px center dot
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primaryForeground,
              ),
            )
          : null,
    );

    if (label != null) {
      return BloomPressable(
        onTap: disabled ? null : () => onChanged?.call(value),
        borderRadius: BorderRadius.circular(999),
        enabled: !disabled,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              circle,
              const SizedBox(width: 8),
              DefaultTextStyle(
                style: TextStyle(
                  color: disabled ? colors.textTertiary : colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: context.bloomTypography.sans,
                ),
                child: label!,
              ),
            ],
          ),
        ),
      );
    }

    return BloomPressable(
      onTap: disabled ? null : () => onChanged?.call(value),
      borderRadius: BorderRadius.circular(999),
      enabled: !disabled,
      child: circle,
    );
  }
}

class BloomRadioOption<T> {
  final T value;
  final Widget label;
  const BloomRadioOption({required this.value, required this.label});
}

/// Radio group container matching shadcn base-nova
class BloomRadioGroup<T> extends StatefulWidget {
  final List<BloomRadioOption<T>>? options;
  final List<Widget>? children;
  final T? value;
  final T? defaultValue;
  final ValueChanged<T>? onChanged;
  final bool disabled;
  final Axis orientation;
  final double spacing;

  const BloomRadioGroup({
    super.key,
    this.options,
    this.children,
    this.value,
    this.defaultValue,
    this.onChanged,
    this.disabled = false,
    this.orientation = Axis.vertical,
    this.spacing = 8,
  }) : assert(options != null || children != null, 'Provide options or children');

  @override
  State<BloomRadioGroup<T>> createState() => _BloomRadioGroupState<T>();
}

class _BloomRadioGroupState<T> extends State<BloomRadioGroup<T>> {
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
  void didUpdateWidget(covariant BloomRadioGroup<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _state = BloomControllableValue<T?>(
        controlledValue: widget.value,
        defaultValue: widget.defaultValue,
        onChanged: widget.onChanged != null ? (v) { if (v != null) widget.onChanged!(v); } : null,
      );
    }
  }

  void _select(T val) {
    if (widget.disabled) return;
    setState(() => _state.update(val));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children != null) {
      return Wrap(
        direction: widget.orientation,
        spacing: widget.spacing,
        runSpacing: widget.spacing,
        children: widget.children!,
      );
    }

    final opts = widget.options!;
    final selected = _state.value;

    final children = opts.map((opt) {
      return BloomRadio<T>(
        value: opt.value,
        groupValue: selected,
        disabled: widget.disabled,
        onChanged: _select,
        label: opt.label,
      );
    }).toList();

    if (widget.orientation == Axis.horizontal) {
      return Wrap(
        spacing: widget.spacing,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children
          .map((c) => Padding(padding: EdgeInsets.only(bottom: widget.spacing), child: c))
          .toList(),
    );
  }
}
