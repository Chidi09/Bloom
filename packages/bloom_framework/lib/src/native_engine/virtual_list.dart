import 'package:flutter/widgets.dart';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'native_renderer.dart';

/// Virtualized recycling sliver/list for ForEachNode on mobile devices.
class BloomVirtualList<T> extends StatelessWidget {
  final ForEachNode<T> node;

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
