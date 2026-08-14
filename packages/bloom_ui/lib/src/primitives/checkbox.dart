// lib/src/primitives/checkbox.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/controllable_value.dart';
import '../utils/extensions.dart';

/// Checkbox component matching shadcn base-nova 16x16px scale with tri-state support.
class BloomCheckbox extends StatefulWidget {
  final bool? checked;
  final bool defaultChecked;
  final ValueChanged<bool?>? onChanged;
  final bool disabled;
  final Widget? label;
  final bool tristate;

  const BloomCheckbox({
    super.key,
    this.checked,
    this.defaultChecked = false,
    this.onChanged,
    this.disabled = false,
    this.label,
    this.tristate = false,
  });

  @override
  State<BloomCheckbox> createState() => _BloomCheckboxState();
}

class _BloomCheckboxState extends State<BloomCheckbox> {
  late BloomControllableValue<bool?> _state;

  @override
  void initState() {
    super.initState();
    _state = BloomControllableValue<bool?>(
      controlledValue: widget.checked,
      defaultValue: widget.defaultChecked,
      onChanged: widget.onChanged,
    );
  }

  @override
  void didUpdateWidget(covariant BloomCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.checked != oldWidget.checked) {
      _state = BloomControllableValue<bool?>(
        controlledValue: widget.checked,
        defaultValue: widget.defaultChecked,
        onChanged: widget.onChanged,
      );
    }
  }

  void _toggle() {
    if (widget.disabled) return;
    bool? next;
    if (widget.tristate) {
      if (_state.value == false) {
        next = true;
      } else if (_state.value == true) {
        next = null;
      } else {
        next = false;
      }
    } else {
      next = !(_state.value ?? false);
    }
    setState(() => _state.update(next));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final value = _state.value;
    final isChecked = value == true;
    final isIndeterminate = value == null;

    final box = AnimatedContainer(
      duration: BloomMotion.instant,
      width: 16, // size-4 (16px)
      height: 16,
      decoration: BoxDecoration(
        color: (isChecked || isIndeterminate) ? colors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(4), // rounded-[4px]
        border: Border.all(
          color: (isChecked || isIndeterminate) ? colors.primary : colors.border,
          width: 1.2,
        ),
      ),
      alignment: Alignment.center,
      child: isChecked
          ? Icon(Icons.check, size: 12, color: colors.primaryForeground)
          : isIndeterminate
              ? Container(
                  width: 8,
                  height: 1.5,
                  color: colors.primaryForeground,
                )
              : null,
    );

    if (widget.label != null) {
      return InkWell(
        onTap: widget.disabled ? null : _toggle,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              box,
              const SizedBox(width: 8),
              DefaultTextStyle(
                style: TextStyle(
                  color: widget.disabled ? colors.textTertiary : colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: context.bloomTypography.sans,
                ),
                child: widget.label!,
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: widget.disabled ? null : _toggle,
      borderRadius: BorderRadius.circular(4),
      child: box,
    );
  }
}
