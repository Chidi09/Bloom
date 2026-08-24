import 'package:flutter/material.dart' hide Text;
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'flex_layout.dart';
import 'input_host.dart';
import 'leaf_render_box.dart';
import 'style_resolver.dart';
import 'virtual_list.dart';

/// Fabric-grade Native AST Renderer translating pure Dart [BloomNode] descriptors into Flutter widgets and render boxes.
///
/// Handles:
/// - [TextNode] ➔ Direct [BloomLeafTextWidget] for zero-overhead text painting
/// - [LiveNode] ➔ Reactive `Watch` widget rebuilding when subscribed signals change
/// - [ShowNode] ➔ Conditional reactive branch switching with optional fallback
/// - [ForEachNode] ➔ Virtualized sliver recycling via [BloomVirtualList]
/// - [FragmentNode] ➔ Flat linear widget lists
/// - [ElNode] ➔ Native [BloomFlexLayout], [BloomNativeInputHost], and styled containers
///
/// Example:
/// ```dart
/// BloomNativeRenderer(
///   node: Div(
///     className: 'p-4 bg-zinc-900 text-white rounded-lg',
///     text: 'Hello from Bloom JS Native!',
///   ),
/// )
/// ```
class BloomNativeRenderer extends StatelessWidget {
  /// The root [BloomNode] AST descriptor to render.
  final BloomNode node;

  /// Creates a [BloomNativeRenderer] widget for the specified [node].
  const BloomNativeRenderer({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final n = node;

    // 1. Text Node (Direct leaf render box)
    if (n is TextNode) {
      final style = BloomComputedStyle();
      return BloomLeafTextWidget(
        textFn: () => n.text,
        style: style,
      );
    }

    // 2. Reactive Live Node
    if (n is LiveNode) {
      return Watch((context) {
        return BloomNativeRenderer(node: n.builder());
      });
    }

    // 3. Conditional Show Node
    if (n is ShowNode) {
      return Watch((context) {
        final isVisible = n.when();
        if (isVisible) {
          return BloomNativeRenderer(node: n.child);
        }
        if (n.fallback != null) {
          return BloomNativeRenderer(node: n.fallback!);
        }
        return const SizedBox.shrink();
      });
    }

    // 4. ForEach Node (Virtualized)
    if (n is ForEachNode) {
      return BloomVirtualList(node: n);
    }

    // 5. Fragment Node
    if (n is FragmentNode) {
      final children = n.children.map((c) => BloomNativeRenderer(node: c)).toList();
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    // 6. Element Node (Div, Span, Button, Input, etc.)
    if (n is ElNode) {
      return _renderElement(context, n);
    }

    return const SizedBox.shrink();
  }

  Widget _renderElement(BuildContext context, ElNode el) {
    final style = BloomStyleResolver.resolve(el.className, inlineStyle: el.style);

    // Special Case: HTML Input / Textarea
    if (el.tag == 'input' || el.tag == 'textarea') {
      final initialVal = el.attrs?['value'];
      final placeholder = el.attrs?['placeholder'];
      final isPassword = el.attrs?['type'] == 'password';
      final onInput = el.on?['input'];
      final onChange = el.on?['change'];

      return BloomNativeInputHost(
        initialValue: initialVal,
        placeholder: placeholder,
        isPassword: isPassword,
        maxLines: el.tag == 'textarea' ? 3 : 1,
        style: style,
        onInput: onInput,
        onChange: onChange,
      );
    }

    // Leaf Text inside Element
    Widget childContent;
    if (el.text != null && el.text!.isNotEmpty) {
      childContent = BloomLeafTextWidget(
        textFn: () => el.text!,
        style: style,
      );
    } else if (el.children.isNotEmpty) {
      final childWidgets = el.children.map((c) => BloomNativeRenderer(node: c)).toList();
      if (style.isFlex) {
        childContent = BloomFlexLayout(
          style: style,
          children: childWidgets,
        );
      } else {
        childContent = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: childWidgets,
        );
      }
    } else {
      childContent = const SizedBox.shrink();
    }

    // Decoration (background, borders, radius)
    BoxDecoration? decoration;
    if (style.backgroundColor != null || style.borderColor != null || style.borderRadius != null) {
      decoration = BoxDecoration(
        color: style.backgroundColor,
        borderRadius: style.borderRadius,
        border: style.borderWidth != null
            ? Border.all(
                color: style.borderColor ?? const Color(0xFF1E1E24),
                width: style.borderWidth!,
              )
            : null,
      );
    }

    Widget result = Container(
      width: style.width,
      height: style.height,
      padding: style.padding.isNonNegative ? style.padding : null,
      margin: style.margin.isNonNegative ? style.margin : null,
      decoration: decoration,
      child: childContent,
    );

    // Touch Actions
    final onClick = el.on?['click'];
    if (onClick != null) {
      result = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onClick(BloomEvent(type: 'click')),
        child: result,
      );
    }

    if (style.flexExpand) {
      result = Expanded(child: result);
    }

    return result;
  }
}
