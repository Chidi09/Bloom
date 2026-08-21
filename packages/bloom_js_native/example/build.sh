#!/usr/bin/env bash
set -e
# Bloom JS Native — example build script (T0: plain dart compile js)
# Requires Dart SDK >=3.3.0
echo "[bloom_js_native] compiling example/main.dart → main.js (O4)..."
dart compile js -O4 -o main.js main.dart
echo "Done. Open index.html in a browser or serve with: npx serve ."
echo "For Bun vendoring (v1): bloom js vendor (coming in M4)"
ls -lh main.js
