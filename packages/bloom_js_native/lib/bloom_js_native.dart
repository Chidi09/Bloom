/// bloom_js_native — the pure-Dart descriptor & SSR runtime (no Flutter, no DOM dependency).
///
/// For browser-only DOM mounting, import `package:bloom_js_native/browser.dart`.
library;

export 'src/framework.dart';
export 'src/html.dart';
export 'src/events.dart';
export 'src/npm.dart';
export 'src/router.dart';

// Re-export signals core primitives so consumers have a single import.
export 'package:signals/signals.dart'
    show signal, computed, effect, batch, untracked, Signal, Computed, ReadonlySignal;
