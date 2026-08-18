// lib/src/web/prerender_bridge.dart
import 'prerender_bridge_stub.dart' if (dart.library.js_interop) 'prerender_bridge_web.dart' as impl;

/// Enables the Flutter semantics/accessibility tree and signals to any
/// headless-browser prerenderer that the app has completed its first
/// meaningful render. No-op outside a web browser context.
void signalPrerenderReady() => impl.signalPrerenderReady();
