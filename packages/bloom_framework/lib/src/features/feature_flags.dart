/// Dynamic, reactive feature flags management engine.
library;

import 'dart:collection';
import '../state/signals.dart';

/// Dynamic, reactive feature flags management engine for Bloom applications.
///
/// Supports runtime flag registration, default values, dynamic overrides,
/// and reactive observation via [ReadonlySignal].
///
/// Example:
/// ```dart
/// final features = BloomFeatureFlags();
/// features.register('new_checkout', defaultValue: false);
///
/// if (features.isEnabled('new_checkout')) {
///   // Show new checkout flow
/// }
/// ```
class BloomFeatureFlags {
  final Map<String, Signal<bool>> _flags = {};
  final Map<String, bool> _defaults = {};

  /// Checks if a feature flag is currently enabled.
  ///
  /// Returns [defaultValue] if [flagName] has not been registered or overridden.
  bool isEnabled(String flagName, {bool defaultValue = false}) {
    if (_flags.containsKey(flagName)) {
      return _flags[flagName]!.value;
    }
    return defaultValue;
  }

  /// Returns a reactive [ReadonlySignal] for a feature flag.
  ///
  /// Widgets observing this signal will automatically rebuild when the flag value changes.
  ///
  /// Example:
  /// ```dart
  /// final isEnabledSig = features.watch('beta_dashboard');
  /// ```
  ReadonlySignal<bool> watch(String flagName, {bool defaultValue = false}) {
    return _getOrCreateSignal(flagName, defaultValue: defaultValue);
  }

  /// Sets or overrides the runtime state of a feature flag.
  ///
  /// Updates the underlying signal and notifies all active listeners immediately.
  void setOverride(String flagName, bool value) {
    final sig = _getOrCreateSignal(flagName, defaultValue: value);
    sig.value = value;
  }

  /// Registers a feature flag with an initial [defaultValue].
  void register(String flagName, {bool defaultValue = false}) {
    _defaults[flagName] = defaultValue;
    if (!_flags.containsKey(flagName)) {
      _flags[flagName] = signal(defaultValue);
    }
  }

  /// Registers multiple feature flags simultaneously from a map.
  ///
  /// Parses string or boolean values.
  void registerAll(Map<String, dynamic> flags) {
    flags.forEach((key, val) {
      final boolVal = val is bool ? val : val.toString().toLowerCase() == 'true';
      _defaults[key] = boolVal;
      if (_flags.containsKey(key)) {
        _flags[key]!.value = boolVal;
      } else {
        _flags[key] = signal(boolVal);
      }
    });
  }

  /// Restores all feature flags to their default registered state.
  void clearOverrides() {
    _flags.forEach((key, sig) {
      sig.value = _defaults[key] ?? false;
    });
  }

  /// Clears all registered flags and state (useful during testing).
  void reset() {
    _flags.clear();
    _defaults.clear();
  }

  /// Returns a snapshot map of all registered feature flag names and their current values.
  Map<String, bool> getAll() {
    final map = <String, bool>{};
    _flags.forEach((k, v) => map[k] = v.value);
    return UnmodifiableMapView(map);
  }

  Signal<bool> _getOrCreateSignal(String name, {required bool defaultValue}) {
    if (!_flags.containsKey(name)) {
      _flags[name] = signal(defaultValue);
      _defaults.putIfAbsent(name, () => defaultValue);
    }
    return _flags[name]!;
  }
}
