// lib/src/primitives/switch.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/controllable_value.dart';
import '../utils/extensions.dart';

class BloomSwitch extends StatefulWidget {
  final bool? checked;
  final bool defaultChecked;
  final ValueChanged<bool>? onChanged;
  final Widget? label;
  final String? description;
  final bool disabled;

  const BloomSwitch({
    super.key,
    this.checked,
    this.defaultChecked = false,
    this.onChanged,
    this.label,
    this.description,
    this.disabled = false,
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
    final next = !_state.value;
    setState(() => _state.update(next));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;
    final isChecked = _state.value;

    final toggle = AnimatedContainer(
      duration: BloomMotion.fast,
      curve: BloomMotion.easeOut,
      width: 44,
      height: 24,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isChecked ? colors.primary : colors.secondary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedAlign(
        duration: BloomMotion.fast,
        curve: BloomMotion.easeOut,
        alignment: isChecked ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Color(0x20000000),
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.label == null) {
      return GestureDetector(onTap: _toggle, child: toggle);
    }

    return GestureDetector(
      onTap: _toggle,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle(
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  child: widget.label!,
                ),
                if (widget.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.description!,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          toggle,
        ],
      ),
    );
  }
}
