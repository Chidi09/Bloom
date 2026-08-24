import 'package:flutter/widgets.dart';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'native_renderer.dart';

/// Virtualized recycling list for [ForEachNode] collections on mobile devices.
///
/// Builds items lazily on demand using Flutter's `ListView.builder` inside a reactive `Watch` wrapper.
///
/// Example:
/// ```dart
/// BloomVirtualList(
///   node: ForEach(
///     () => itemsSignal.value,
///     (item) => Div(text: item.name),
///   ),
/// )
/// ```
class BloomVirtualList<T> extends StatelessWidget {
  /// The [ForEachNode] defining the collection evaluation and item template builder.
  final ForEachNode<T> node;

  /// Creates a [BloomVirtualList] widget for [node].
  const BloomVirtualList({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final items = node.items();
      if (items.isEmpty) return const SizedBox.shrink();

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final childNode = node.builder(item);
          return BloomNativeRenderer(node: childNode);
        },
      );
    });
  }
}
