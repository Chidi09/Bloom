// lib/src/state/watch.dart
import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart' as sf;

/// A builder widget that rebuilds whenever any signal read inside [builder] changes.
class SignalBuilder extends StatelessWidget {
  final Widget Function(BuildContext context) builder;

  const SignalBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return sf.Watch((ctx) => builder(ctx));
  }
}
