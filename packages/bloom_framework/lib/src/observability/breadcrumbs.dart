// lib/src/observability/breadcrumbs.dart
import 'dart:collection';
import 'models.dart';

/// Fixed-capacity ring buffer for storing recent chronological breadcrumbs.
class BloomBreadcrumbRingBuffer {
  final int maxCapacity;
  final Queue<BloomBreadcrumb> _queue = Queue<BloomBreadcrumb>();

  BloomBreadcrumbRingBuffer({this.maxCapacity = 100}) {
    if (maxCapacity <= 0) {
      throw ArgumentError.value(maxCapacity, 'maxCapacity', 'Must be greater than 0');
    }
  }

  /// Adds a breadcrumb to the ring buffer, evicting the oldest if capacity is exceeded.
  void add(BloomBreadcrumb breadcrumb) {
    if (_queue.length >= maxCapacity) {
      _queue.removeFirst();
    }
    _queue.addLast(breadcrumb);
  }

  /// Returns a snapshot copy of all breadcrumbs in chronological order.
  List<BloomBreadcrumb> toList() => List<BloomBreadcrumb>.unmodifiable(_queue);

  /// Current number of breadcrumbs in the buffer.
  int get length => _queue.length;

  /// Whether the buffer is empty.
  bool get isEmpty => _queue.isEmpty;

  /// Clears all breadcrumbs from the buffer.
  void clear() {
    _queue.clear();
  }
}
