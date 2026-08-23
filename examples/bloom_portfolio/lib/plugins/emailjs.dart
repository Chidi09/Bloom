// Typed wrapper around `@emailjs/browser` (installed via
// `bloom add npm:@emailjs/browser` — see bloom.yaml / web/index.html). Loaded
// as an ES module through the import map in web/index.html; its bootstrap
// <script type="module"> assigns the default export to `window.emailjs`
// for this binding to find.
library;

import 'dart:js_interop';

@JS('emailjs')
extension type _EmailJsModule._(JSObject _) implements JSObject {
  external void init(JSAny options);
  external JSPromise send(
    JSString serviceId,
    JSString templateId,
    JSObject templateParams, [
    JSAny? publicKeyOrOptions,
  ]);
}

@JS('emailjs')
external _EmailJsModule? get _emailJs;

/// Client-side email dispatch service interfacing with EmailJS.
class EmailJs {
  /// Initializes EmailJS globally with [publicKey].
  static void init(String publicKey) {
    try {
      _emailJs?.init(publicKey.toJS);
    } catch (_) {}
  }

  /// Sends a templated email with [templateParams] using the specified service
  /// and template IDs.
  static Future<bool> send({
    required String serviceId,
    required String templateId,
    required String publicKey,
    required Map<String, String> templateParams,
  }) async {
    try {
      final module = _emailJs;
      if (module == null) return false;
      final paramsJs = templateParams.jsify() as JSObject;
      final promise = module.send(
        serviceId.toJS,
        templateId.toJS,
        paramsJs,
        publicKey.toJS,
      );
      final res = await promise.toDart;
      return res != null;
    } catch (_) {
      return false;
    }
  }
}
