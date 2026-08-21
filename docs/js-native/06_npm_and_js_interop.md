# 06 — NPM Ecosystem & JavaScript Interop

Bloom JS Native provides surgical NPM consumption. You can install, bundle, and invoke any ESM-compatible JavaScript package from Dart using modern `dart:js_interop` extension types without shipping entire `node_modules` folders to production.

---

## 1. Declaring NPM Dependencies in `bloom.yaml`

Add your required NPM packages to `bloom.yaml`:

```yaml
name: my_bloom_app
target: web_dom

npm_packages:
  three:
    npm_name: three
    version: 0.160.0
    vendor_file: web/vendor/three.min.js
    dart_binding: lib/plugins/three_js.dart

  chart.js:
    npm_name: chart.js
    version: 4.4.1
    vendor_file: web/vendor/chart.min.js
    dart_binding: lib/plugins/chart_js.dart

  canvas-confetti:
    npm_name: canvas-confetti
    version: 1.9.3
    vendor_file: web/vendor/canvas-confetti.min.js
```

---

## 2. Vendoring with Bun (`bloom js vendor`)

Run the vendor toolchain:

```bash
bloom js vendor
```

- If **Bun** is installed, Bloom creates an isolated ESM bundle with `bun build --minify` into `web/vendor/`.
- If Bun is absent, Bloom resolves and downloads the exact pinned version via CDN fallback.

---

## 3. Writing Zero-Cost `dart:js_interop` Bindings

Use Dart 3.5+ `extension type` to wrap JavaScript ES6 classes with full static typing and zero runtime overhead:

```dart
// lib/plugins/chart_js.dart
import 'dart:js_interop';
import 'package:web/web.dart' as web;

@JS('Chart')
extension type Chart._(JSObject _) implements JSObject {
  // Invokes `new Chart(canvas, config)`
  external Chart(web.HTMLCanvasElement canvas, JSObject config);
}

class ChartHelper {
  static void renderBarChart(web.HTMLCanvasElement canvas, List<double> values) {
    final config = <String, dynamic>{
      'type': 'bar',
      'data': {
        'labels': ['Q1', 'Q2', 'Q3', 'Q4'],
        'datasets': [
          {
            'label': 'Throughput',
            'data': values,
            'backgroundColor': '#6366F1',
          }
        ]
      }
    }.jsify() as JSObject;

    Chart(canvas, config);
  }
}
```

---

## 4. Canvas Confetti Example

```dart
// lib/plugins/confetti.dart
import 'dart:js_interop';

@JS('confetti')
external void _confetti(JSObject? options);

class Confetti {
  static void burst({double x = 0.5, double y = 0.5}) {
    try {
      final opts = <String, dynamic>{
        'particleCount': 60,
        'spread': 70,
        'origin': {'x': x, 'y': y},
        'colors': ['#6366F1', '#8B5CF6', '#06B6D4', '#10B981'],
      }.jsify() as JSObject;

      _confetti(opts);
    } catch (_) {}
  }
}
```
