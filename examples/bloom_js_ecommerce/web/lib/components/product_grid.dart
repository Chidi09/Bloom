import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:web/web.dart' as web;
import '../plugins/lucide_icons.dart';
import '../state/store.dart';

class ProductGridComponent {
  final EcommerceStore store;
  final Ref<web.Element> _scrollRef = Ref<web.Element>();
  late final BloomVirtualizer _virtualizer = BloomVirtualizer(
    scrollElementRef: _scrollRef,
    count: () {
      final data = store.productsQuery.data.value;
      if (data == null) return 0;
      return (data.length / 3).ceil();
    },
    estimateSize: (i) => 280,
  );
  int _lastRowCount = -1;
  bool _attached = false;

  ProductGridComponent(this.store);

  BloomNode build() {
    return Main(
      // w-full: don't rely on implicit flex cross-axis stretch to give
      // this its width — pin it explicitly so max-w-6xl/mx-auto centering
      // has an unambiguous 100%-of-parent starting point to shrink from.
      className: 'w-full max-w-6xl mx-auto px-6 py-10',
      children: [
        H1(className: 'text-2xl font-bold text-white mb-6', text: 'Products'),
        Live(() {
          final query = store.productsQuery;
          if (query.isLoading) {
            return P(className: 'text-zinc-400', text: 'Loading products...');
          }
          if (query.isError) {
            return P(
              className: 'text-red-400',
              text: 'Failed to load products: ${query.error.value}',
            );
          }
          final products = query.data.value ?? const [];
          if (products.isEmpty) {
            return P(className: 'text-zinc-400', text: 'No products available yet.');
          }
          final rowCount = (products.length / 3).ceil();
          if (rowCount != _lastRowCount) {
            _lastRowCount = rowCount;
            // Only push a live setOptions/refresh if the scroll element is
            // already mounted — the very first population races with
            // Mount's onMount, so let onMount's own refresh() (below) pick
            // up the initial count instead of touching the still-unattached
            // Ref here.
            if (_attached) {
              _virtualizer.refresh();
            }
          }
          return RefNode(
            _scrollRef,
            Mount(
              Div(
                className: 'h-[75vh] overflow-y-auto relative',
                children: [
                  Live(() {
                    final items = _virtualizer.items.value;
                    final total = _virtualizer.totalSize.value;
                    return Div(
                      style: 'height: ${total}px; position: relative;',
                      children: items.map((item) {
                        final startIndex = item.index * 3;
                        final rowProducts = products.skip(startIndex).take(3).toList();
                        return Div(
                          style:
                              'position: absolute; top: ${item.start}px; left: 0; right: 0; height: ${item.size}px;',
                          children: [
                            Div(
                              // Fixed 3 columns unconditionally (no
                              // responsive breakpoints): the virtualizer
                              // windows rows-of-3 with a fixed pixel row
                              // height, so the on-screen column count must
                              // always match 3 or a row wraps to more lines
                              // than the fixed row box can hold and bleeds
                              // into the next absolutely-positioned row.
                              className: 'grid grid-cols-3 gap-6',
                              children: rowProducts.map((raw) {
                                final p = raw as Map<String, dynamic>;
                                final id = p['id'] as int;
                                final priceCents = p['priceCents'] as int? ?? 0;
                                final stock = p['stockQuantity'] as int? ?? 0;
                                return Div(
                                  className:
                                      // Fixed height + overflow-hidden so
                                      // every card is guaranteed to fit
                                      // inside the row's fixed 280px pixel
                                      // budget regardless of description
                                      // length.
                                      'h-64 overflow-hidden rounded-xl border border-zinc-800 bg-[#131318] p-5 flex flex-col gap-2',
                                  children: [
                                    H3(
                                        className: 'text-white font-semibold',
                                        text: p['name'] as String? ?? ''),
                                    P(
                                        className: 'text-zinc-400 text-sm flex-1 line-clamp-3',
                                        text: p['description'] as String? ?? ''),
                                    Div(
                                      className: 'flex items-center justify-between mt-2',
                                      children: [
                                        Span(
                                          className: 'text-lg font-bold text-emerald-400',
                                          text: '\$${(priceCents / 100).toStringAsFixed(2)}',
                                        ),
                                        Span(
                                          className: 'text-xs text-zinc-500',
                                          text: stock > 0 ? '$stock in stock' : 'Out of stock',
                                        ),
                                      ],
                                    ),
                                    Button(
                                      className: stock > 0
                                          ? 'mt-3 px-4 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-medium flex items-center justify-center gap-1.5'
                                          : 'mt-3 px-4 py-2 rounded-lg bg-zinc-800 text-zinc-500 text-sm font-medium cursor-not-allowed flex items-center justify-center gap-1.5',
                                      onClick: stock > 0 ? (_) => store.addToCart(id) : null,
                                      children: [
                                        Raw(LucideIcons.svg(LucideIconName.shoppingCart,
                                            className: 'w-4 h-4')),
                                        Span(text: 'Add to cart'),
                                      ],
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      }).toList(),
                    );
                  }),
                ],
              ),
              onMount: () {
                _attached = true;
                _virtualizer.attach();
                // The virtualizer was constructed (and possibly already
                // attach()-built) against whatever count() returned before
                // mount — refresh once now so it re-measures against the
                // real, current row count.
                _virtualizer.refresh();
              },
              onUnmount: () {
                _attached = false;
                _virtualizer.dispose();
              },
            ),
          );
        }),
      ],
    );
  }
}
