/// Headless prerenderer signaling bridge for Bloom Web applications.
library;

import 'prerender_bridge_stub.dart' if (dart.library.js_interop) 'prerender_bridge_web.dart' as impl;

/// Enables the Flutter semantics/accessibility tree and signals to any
/// headless-browser prerenderer (such as Puppeteer/Chromium SSG) that the app
/// has completed its first meaningful render frame.
///
/// Automatically invoked by [BloomApp] upon mounting. No-op outside a web browser context.
///
/// Example:
/// ```dart
/// signalPrerenderReady();
/// ```
void signalPrerenderReady() => impl.signalPrerenderReady();

