// lib/src/web/prerender_bridge_web.dart
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/semantics.dart';
import 'package:web/web.dart' as web;

/// Enables Flutter semantics tree and signals to headless prerenderer
/// that the initial frame has finished rendering.
void signalPrerenderReady() {
  try {
    SemanticsBinding.instance.ensureSemantics();
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      try {
        web.window.setProperty('__BLOOM_PRERENDER_READY__'.toJS, true.toJS);
      } catch (_) {}
    });
  } catch (_) {}
}
