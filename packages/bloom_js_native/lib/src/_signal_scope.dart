import 'dart:async';
import '_signal_scope_registry_stub.dart'
    if (dart.library.js_interop) '_signal_scope_registry_browser.dart'
    as registry;

const Object _signalScopeZoneKey = #bloomHotReloadSignalScope;

/// Runs [callback] with a stable, nested scope for hot-reload signal keys.
///
/// The length-prefixed encoding keeps arbitrary list keys unambiguous when
/// scopes are nested.
T runWithBloomSignalScope<T>(String segment, T Function() callback) {
  return runWithBloomSignalScopeValue(
      composeBloomSignalScope(segment), callback);
}

/// Re-enters a previously captured full scope, independent of the caller's
/// current Zone. Reactive callbacks can run later from browser event handlers,
/// where the original parent scope is no longer ambient.
T runWithBloomSignalScopeValue<T>(String? scope, T Function() callback) {
  if (scope == null) return callback();
  return runZoned(callback, zoneValues: {_signalScopeZoneKey: scope});
}

/// Re-enters a captured signal-scope boundary, including a captured `null`.
///
/// A reactive callback may be notified synchronously from an event handler that
/// runs in a nested item scope. Restoring `null` prevents that caller's scope
/// from leaking into a callback that was originally created outside any scope.
T runWithBloomSignalScopeBoundary<T>(String? scope, T Function() callback) {
  return runZoned(callback, zoneValues: {_signalScopeZoneKey: scope});
}

String? get currentBloomSignalScope =>
    Zone.current[_signalScopeZoneKey] as String?;

/// Stable full scope value that [runWithBloomSignalScope] will install for
/// [segment] from the current zone.
String composeBloomSignalScope(String segment) {
  final parent = currentBloomSignalScope;
  return parent == null ? _encode(segment) : '$parent${_encode(segment)}';
}

void registerBloomScopedSignal(String scope, String key) =>
    registry.registerScopedSignal(scope, key);

void releaseBloomSignalScope(String? scope) {
  if (scope != null) registry.releaseSignalScope(scope);
}

void forgetBloomScopedSignal(String key) => registry.forgetScopedSignal(key);

void beginBloomSignalScopeTransition() => registry.beginSignalScopeTransition();

void finishBloomSignalScopeTransition() =>
    registry.finishSignalScopeTransition();

String _encode(String value) => '${value.length}:$value';
