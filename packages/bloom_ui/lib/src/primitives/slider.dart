// lib/src/primitives/slider.dart
import 'package:flutter/material.dart';
import '../utils/extensions.dart';

class BloomSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final ValueChanged<double>? onChanged;
  final bool disabled;

  const BloomSlider({
    super.key,
    required this.value,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.label,
    required this.onChanged,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.bloomColors;

    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.secondary,
        thumbColor: colors.primary,
        overlayColor: colors.primary.withValues(alpha: 0.15),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        label: label,
        onChanged: disabled ? null : onChanged,
      ),
    );
  }
}
