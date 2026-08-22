// lib/src/devtools.dart
//
// Runtime diagnostics and DevTools inspection hooks for Bloom JS Native.
import 'framework.dart';

class BloomJsDevTools {
  BloomJsDevTools._();

  static int activeRegionCount = 0;
  static int activeSentinelCount = 0;

  static final List<void Function(String event, Map<String, dynamic> data)>
      _listeners = [];

  /// Register a diagnostics event listener. Returns an unregister callback.
  static void Function() addListener(
      void Function(String event, Map<String, dynamic> data) listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  /// Maximum number of events retained in [eventLog]. Oldest events are
  /// dropped once this limit is exceeded.
  static const int maxEventLogSize = 200;

  static final List<BloomDevToolsEvent> _eventLog = [];

  /// Read-only view of the most recent diagnostic events, oldest first.
  /// Bounded to [maxEventLogSize] entries.
  static List<BloomDevToolsEvent> get eventLog => List.unmodifiable(_eventLog);

  /// Clears the event log. Does not affect registered listeners or counters.
  static void clearEventLog() => _eventLog.clear();

  /// Dispatches a diagnostic event to all registered listeners and appends
  /// it to [eventLog].
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

  /// Serializes [node] and its descendants into a plain, JSON-encodable
  /// `Map` for external inspection (a browser extension, a CLI inspector,
  /// or a test assertion). Best-effort: node types with no explicit case
  /// below are summarized generically via their runtime type name.
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

/// A single recorded diagnostics event.
class BloomDevToolsEvent {
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const BloomDevToolsEvent({
    required this.type,
    required this.data,
    required this.timestamp,
  });

  @override
  String toString() => 'BloomDevToolsEvent($type, $data, $timestamp)';
}
