// lib/src/primitives/switch.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/controllable_value.dart';
import '../utils/extensions.dart';

enum BloomSwitchSize {
  defaultSize, // 32x18px, 16px thumb
  sm,          // 24x14px, 12px thumb
}

/// Animated toggle switch matching shadcn base-nova dimensions.
class BloomSwitch extends StatefulWidget {
  final bool? checked;
  final bool defaultChecked;
  final ValueChanged<bool>? onChanged;
  final bool disabled;
  final BloomSwitchSize size;
  final Widget? label;

  const BloomSwitch({
    super.key,
    this.checked,
    this.defaultChecked = false,
    this.onChanged,
    this.disabled = false,
    this.size = BloomSwitchSize.defaultSize,
    this.label,
  });

  @override
  State<BloomSwitch> createState() => _BloomSwitchState();
}

class _BloomSwitchState extends State<BloomSwitch> {
  late BloomControllableValue<bool> _state;

  @override
  void initState() {
    super.initState();
    _state = BloomControllableValue<bool>(
      controlledValue: widget.checked,
      defaultValue: widget.defaultChecked,
      onChanged: widget.onChanged,
    );
  }

  @override
  void didUpdateWidget(covariant BloomSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.checked != oldWidget.checked) {
      _state = BloomControllableValue<bool>(
        controlledValue: widget.checked,
        defaultValue: widget.defaultChecked,
        onChanged: widget.onChanged,
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
    final isChecked = _state.value;
    final isSm = widget.size == BloomSwitchSize.sm;

    final width = isSm ? 24.0 : 32.0;
    final height = isSm ? 14.0 : 18.0;
    final thumbSize = isSm ? 10.5 : 14.0;
    final padding = (height - thumbSize) / 2;

    final track = AnimatedContainer(
      duration: BloomMotion.fast,
      width: width,
      height: height,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: isChecked ? colors.primary : colors.border,
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedAlign(
        duration: BloomMotion.fast,
        curve: BloomMotion.easeOut,
        alignment: isChecked ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: thumbSize,
          height: thumbSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.primaryForeground,
            boxShadow: const [BloomShadows.s1],
          ),
        ),
      ),
    );

    if (widget.label != null) {
      return InkWell(
        onTap: widget.disabled ? null : _toggle,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              track,
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
      borderRadius: BorderRadius.circular(999),
      child: track,
    );
  }
}
