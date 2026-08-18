// lib/src/state/watch.dart
import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart' as sf;

/// A typed builder widget that rebuilds whenever the targeted [signal] value changes.
class SignalBuilder<T> extends StatelessWidget {
  /// The signal instance to observe.
  final sf.ReadonlySignal<T> signal;

  /// The builder callback invoked with the current [signal] value whenever it updates.
  final Widget Function(BuildContext context, T value) builder;

  /// Creates a [SignalBuilder] watching [signal].
  const SignalBuilder({
    super.key,
    required this.signal,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return sf.Watch((ctx) => builder(ctx, signal.value));
  }
}
