import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('Reflect.get')
external JSAny? _reflectGet(JSAny target, String key);

@JS('Reflect.set')
external bool _reflectSet(JSAny target, String key, JSAny? value);

const String _signalRegistryProp = '__bloom_signal_registry__';
const String _scopeRegistryProp = '__bloom_signal_scope_registry__';
const String _scopeTransitionProp = '__bloom_signal_scope_transition__';
const int _maxTrackedScopeKeys = 512;

void registerScopedSignal(String scope, String key) {
  final scopes = _getScopeRegistry();
  if (scopes == null) return;
  scopes.putIfAbsent(scope, () => <String>{}).add(key);

  // Keep bookkeeping bounded with the value registry. Dropping an old scope
  // also drops its signal values, which will safely reset if it is rendered
  // again later in this development session.
  while (scopes.length > _maxTrackedScopeKeys) {
    _removeScope(scopes.keys.first);
  }
}

void releaseSignalScope(String scope) {
  final win = web.window as JSAny;
  if (_getBool(win, _scopeTransitionProp)) return;
  _removeScope(scope);
}

void forgetScopedSignal(String key) {
  final scopes = _getScopeRegistry();
  if (scopes == null) return;
  final emptyScopes = <String>[];
  for (final entry in scopes.entries) {
    entry.value.remove(key);
    if (entry.value.isEmpty) emptyScopes.add(entry.key);
  }
  for (final scope in emptyScopes) {
    scopes.remove(scope);
  }
}

void beginSignalScopeTransition() {
  final win = web.window as JSAny;
  _reflectSet(win, _scopeTransitionProp, true.toJS);
}

void finishSignalScopeTransition() {
  final win = web.window as JSAny;
  _reflectSet(win, _scopeTransitionProp, false.toJS);
}

void _removeScope(String scope) {
  final scopes = _getScopeRegistry();
  final keys = scopes?.remove(scope);
  if (keys == null || keys.isEmpty) return;
  final registry = _getSignalRegistry();
  if (registry == null) return;
  for (final key in keys) {
    registry.remove(key);
  }
}

Map<String, Object?>? _getSignalRegistry() {
  final boxed = _reflectGet(web.window as JSAny, _signalRegistryProp);
  if (boxed == null || !boxed.isA<JSBoxedDartObject>()) return null;
  final value = (boxed as JSBoxedDartObject).toDart;
  return value is Map<String, Object?> ? value : null;
}

Map<String, Set<String>>? _getScopeRegistry() {
  final win = web.window as JSAny;
  final boxed = _reflectGet(win, _scopeRegistryProp);
  if (boxed != null && boxed.isA<JSBoxedDartObject>()) {
    final value = (boxed as JSBoxedDartObject).toDart;
    if (value is Map<String, Set<String>>) return value;
  }
  final registry = <String, Set<String>>{};
  return _reflectSet(win, _scopeRegistryProp, registry.toJSBox)
      ? registry
      : null;
}

bool _getBool(JSAny win, String key) {
  return _reflectGet(win, key)?.dartify() == true;
}
