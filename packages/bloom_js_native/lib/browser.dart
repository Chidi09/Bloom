/// Browser-only entry point for Bloom JS Native.
///
/// The core library (`package:bloom_js_native/bloom_js_native.dart`) is
/// pure Dart — descriptor trees, HTML rendering, npm registry, router
/// matching — so it loads and tests on the plain VM. This library adds the
/// real-DOM backend (`package:web` + `dart:js_interop`).
///
/// Web apps import both:
///
/// ```dart
/// import 'package:bloom_js_native/bloom_js_native.dart';
/// import 'package:bloom_js_native/browser.dart';
///
/// void main() {
///   mount(App(), '#app');
/// }
/// ```
library;

export 'src/mount.dart';
export 'src/router_browser.dart';
export 'src/hydrate.dart';
export 'src/virtual.dart';
export 'src/islands.dart';
export 'src/web_components.dart';
