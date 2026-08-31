import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'mount.dart';

@JS('Reflect.get')
external JSAny? _reflectGet(JSAny target, String key);

@JS('Reflect.set')
external bool _reflectSet(JSAny target, String key, JSAny? value);

const String _bloomSignalRegistryProp = '__bloom_signal_registry__';

bool isBrowserHotReloadActive() => isHotReloadTrackingActive();

Map<String, Object?>? getBrowserSignalRegistry() {
  try {
    final win = web.window as JSAny;
    final boxed = _reflectGet(win, _bloomSignalRegistryProp);
    if (boxed != null && boxed.isA<JSBoxedDartObject>()) {
      final dartObj = (boxed as JSBoxedDartObject).toDart;
      if (dartObj is Map<String, Object?>) {
        return dartObj;
      }
    }
    final map = <String, Object?>{};
    _reflectSet(win, _bloomSignalRegistryProp, map.toJSBox);
    return map;
  } catch (_) {
    return null;
  }
}
