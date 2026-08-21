# Changelog

## 0.1.0 - 2026-08-21

* Initial release of `bloom_js_native`.
* Pure Dart AST descriptor tree (`BloomNode`, `ElNode`, `TextNode`, `LiveNode`, `ShowNode`, `ForEachNode`, `FragmentNode`).
* Fine-grained signals reactivity binding (`signal`, `computed`, `effect`, `batch`).
* Dual-backend architecture:
  * Browser DOM mounting via `package:bloom_js_native/browser.dart` (`package:web`).
  * Instant sub-millisecond SSR via `renderToHtml()` with automatic XSS escaping.
* Built-in NPM vendor manager & ESM importmaps (`NpmRegistry`).
* HTML element subclasses (`Div`, `Span`, `Button`, `Input`, `Form`, `H1`–`H6`, etc.) ensuring 0 analyzer warnings.
