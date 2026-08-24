/// Visual inspection engine for the Bloom Signals state tree in DevTools.
library;

import 'dart:collection';
import '../state/signals.dart';

/// Visual descriptor for a tracked reactive signal displayed in DevTools.
///
/// Contains the signal name/label, current value, update count, and runtime type.
///
/// Example:
/// ```dart
/// final desc = SignalDescriptor(
///   name: 'counter',
///   currentValue: 42,
///   updateCount: 5,
///   valueType: int,
/// );
/// ```
class SignalDescriptor {
  /// Debug label or signal name.
  final String name;

  /// Current evaluated signal value.
  final dynamic currentValue;

  /// Total count of value update notifications observed.
  final int updateCount;

  /// Runtime type of the signal value.
  final Type valueType;

  /// Creates a [SignalDescriptor].
  SignalDescriptor({
    required this.name,
    required this.currentValue,
    required this.updateCount,
    required this.valueType,
  });

  /// Serializes descriptor to a JSON map.
  Map<String, dynamic> toJson() => {
        'name': name,
        'currentValue': currentValue,
        'updateCount': updateCount,
        'valueType': valueType.toString(),
      };
}

/// Visual inspection engine for the Bloom Signals state tree.
///
/// Allows DevTools to register, observe, and remotely update signal values at runtime.
///
/// Example:
/// ```dart
/// BloomSignalsInspector.trackSignal('themeMode', themeSignal);
/// final signals = BloomSignalsInspector.inspectAll();
/// ```
class BloomSignalsInspector {
  static final Map<String, Signal<dynamic>> _trackedSignals = {};
  static final Map<String, int> _updateCounts = {};

  /// Registers a signal instance for visual DevTools inspection.
  static void trackSignal(String name, Signal<dynamic> sig) {

    _trackedSignals[name] = sig;
    _updateCounts.putIfAbsent(name, () => 0);
  }

  /// Untracks a signal when disposed.
  static void untrackSignal(String name) {
    _trackedSignals.remove(name);
    _updateCounts.remove(name);
  }

  /// Returns snapshots of all currently tracked signals.
  static List<SignalDescriptor> inspectAll() {
    final list = <SignalDescriptor>[];
    _trackedSignals.forEach((name, sig) {
      list.add(SignalDescriptor(
        name: name,
        currentValue: sig.value,
        updateCount: _updateCounts[name] ?? 0,
        valueType: sig.value.runtimeType,
      ));
    });
    return UnmodifiableListView(list);
  }

  /// Updates a signal's value remotely from DevTools.
  static void setSignalValue(String name, dynamic newValue) {
    if (_trackedSignals.containsKey(name)) {
      _trackedSignals[name]!.value = newValue;
      _updateCounts[name] = (_updateCounts[name] ?? 0) + 1;
    }
  }

  /// Clears all tracked signals.
  static void clear() {
    _trackedSignals.clear();
    _updateCounts.clear();
  }
}
