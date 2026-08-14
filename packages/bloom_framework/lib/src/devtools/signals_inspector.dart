// lib/src/devtools/signals_inspector.dart
import 'dart:collection';
import '../state/signals.dart';

class SignalDescriptor {
  final String name;
  final dynamic currentValue;
  final int updateCount;
  final Type valueType;

  SignalDescriptor({
    required this.name,
    required this.currentValue,
    required this.updateCount,
    required this.valueType,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'currentValue': currentValue,
        'updateCount': updateCount,
        'valueType': valueType.toString(),
      };
}

/// Visual inspection engine for Bloom Signals state tree.
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
