// lib/src/utils/controllable_value.dart
import 'package:flutter/material.dart';

/// Helper class to bridge controlled and uncontrolled widget state patterns.
class BloomControllableValue<T> {
  final T? controlledValue;
  final T defaultValue;
  final ValueChanged<T>? onChanged;

  late T _internalValue;

  BloomControllableValue({
    required this.controlledValue,
    required this.defaultValue,
    this.onChanged,
  }) {
    _internalValue = controlledValue ?? defaultValue;
  }

  bool get isControlled => controlledValue != null;
  T get value => isControlled ? controlledValue! : _internalValue;

  void update(T newValue) {
    if (!isControlled) {
      _internalValue = newValue;
    }
    onChanged?.call(newValue);
  }
}
