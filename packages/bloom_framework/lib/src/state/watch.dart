// lib/src/state/watch.dart
import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart' as sf;

/// A typed builder widget that rebuilds whenever the targeted [signal] value changes.
class SignalBuilder<T> extends StatelessWidget {
  final sf.ReadonlySignal<T> signal;
  final Widget Function(BuildContext context, T value) builder;

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
