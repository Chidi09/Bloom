// lib/src/devtools.dart
//
// Runtime diagnostics and DevTools inspection hooks for Bloom JS Native.
import 'framework.dart';

/// Runtime diagnostics and inspection interface for development-time tooling.
///
/// **Note**: This is a development-only surface used by browser extensions, dev servers,
/// test runners, and diagnostic consoles to inspect active DOM regions, sentinels,
/// lifecycle events, and component AST trees.
///
/// In production builds, listeners and log events should remain unpopulated to avoid
/// unnecessary overhead.
///
/// ```dart
/// // Listen to framework diagnostic events
/// final unsubscribe = BloomJsDevTools.addListener((event, data) {
///   print('DevTools event: $event, payload: $data');
/// });
///
/// // Serialize an AST node to a JSON map
/// final snapshot = BloomJsDevTools.snapshotTree(
///   Div(className: 'card', text: 'Hello'),
/// );
/// ```
class BloomJsDevTools {
  BloomJsDevTools._();

  /// Current number of actively mounted reactive region scopes in the browser DOM.
  static int activeRegionCount = 0;

  /// Current number of active sentinel comment boundary markers in the browser DOM.
  static int activeSentinelCount = 0;

  static final List<void Function(String event, Map<String, dynamic> data)>
      _listeners = [];

  /// Registers a diagnostic event [listener] callback.
  ///
  /// Returns a zero-argument function that unregisters the listener when called.
  static void Function() addListener(
      void Function(String event, Map<String, dynamic> data) listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  /// Maximum number of diagnostic events retained in [eventLog].
  ///
  /// Once this limit is reached, the oldest events are evicted as new ones arrive.
  static const int maxEventLogSize = 200;

  static final List<BloomDevToolsEvent> _eventLog = [];

  /// Unmodifiable view of the most recent diagnostic events, ordered from oldest to newest.
  ///
  /// Bounded to [maxEventLogSize] entries.
  static List<BloomDevToolsEvent> get eventLog => List.unmodifiable(_eventLog);

  /// Clears the in-memory diagnostic event log without modifying listeners or active counters.
  static void clearEventLog() => _eventLog.clear();

  /// Dispatches a diagnostic [event] with [data] to all registered listeners and logs it to [eventLog].
  static void notify(String event, Map<String, dynamic> data) {
    _eventLog.add(BloomDevToolsEvent(
      type: event,
      data: data,
      timestamp: DateTime.now(),
    ));
    while (_eventLog.length > maxEventLogSize) {
      _eventLog.removeAt(0);
    }
    for (final listener in List.of(_listeners)) {
      try {
        listener(event, data);
      } catch (_) {}
    }
  }

  /// Serializes [node] and its descendant subtree into a JSON-encodable [Map].
  ///
  /// Useful for browser DevTools extensions, snapshot assertions in tests, or external CLI inspectors.
  /// Unrecognized custom node types are serialized generically by runtime type name.
  ///
  /// ```dart
  /// final snapshot = BloomJsDevTools.snapshotTree(
  ///   Div(className: 'btn', text: 'Click me'),
  /// );
  /// // Produces:
  /// // {'kind': 'element', 'tag': 'div', 'className': 'btn', 'text': 'Click me', 'children': []}
  /// ```
  static Map<String, dynamic> snapshotTree(BloomNode node) {
    return switch (node) {
      ElNode(:final tag, :final text, :final className, :final attrs, :final children) => {
          'kind': 'element',
          'tag': tag,
          if (text != null) 'text': text,
          if (className != null) 'className': className,
          if (attrs != null && attrs.isNotEmpty) 'attrs': attrs,
          'children': [for (final child in children) snapshotTree(child)],
        },
      TextNode(:final text) => {
          'kind': 'text',
          'text': text,
        },
      FragmentNode(:final children) => {
          'kind': 'fragment',
          'children': [for (final child in children) snapshotTree(child)],
        },
      _ => {
          'kind': 'node',
          'type': node.runtimeType.toString(),
        },
    };
  }
}

/// A recorded diagnostic event emitted by [BloomJsDevTools.notify].
class BloomDevToolsEvent {
  /// The diagnostic event identifier string (e.g. `'mount-error'`, `'region-created'`).
  final String type;

  /// Structured event payload metadata.
  final Map<String, dynamic> data;

  /// Timestamp when the diagnostic event occurred.
  final DateTime timestamp;

  /// Creates a diagnostic event record.
  const BloomDevToolsEvent({
    required this.type,
    required this.data,
    required this.timestamp,
  });

  @override
  String toString() => 'BloomDevToolsEvent($type, $data, $timestamp)';
}
