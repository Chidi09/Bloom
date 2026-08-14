// lib/src/primitives/checkbox.dart
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../utils/controllable_value.dart';
import '../utils/extensions.dart';

class BloomCheckbox extends StatefulWidget {
  final bool? checked;
  final bool defaultChecked;
  final ValueChanged<bool>? onChanged;
  final Widget? label;
  final String? description;
  final bool disabled;

  const BloomCheckbox({
    super.key,
    this.checked,
    this.defaultChecked = false,
    this.onChanged,
    this.label,
    this.description,
    this.disabled = false,
  });

  @override
  State<BloomCheckbox> createState() => _BloomCheckboxState();
}

class _BloomCheckboxState extends State<BloomCheckbox> {
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
  void didUpdateWidget(covariant BloomCheckbox oldWidget) {
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

    final box = AnimatedContainer(
      duration: BloomMotion.instant,
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: isChecked ? colors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isChecked ? colors.primary : colors.border,
          width: 1.5,
        ),
      ),
      child: isChecked
          ? const Icon(Icons.check, size: 13, color: Colors.white)
          : null,
    );

    if (widget.label == null) {
      return GestureDetector(onTap: _toggle, child: box);
    }

    return GestureDetector(
      onTap: _toggle,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2.0), child: box),
          const SizedBox(width: 10),
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
        ],
      ),
    );
  }
}
