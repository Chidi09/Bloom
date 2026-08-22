import 'package:bloom_js_native/bloom_js_native.dart';
import '../state/store.dart';

class ProductGridComponent {
  final EcommerceStore store;
  ProductGridComponent(this.store);

  BloomNode build() {
    return Main(
      className: 'max-w-6xl mx-auto px-6 py-10',
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
          return Div(
            className: 'grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6',
            children: products.map((raw) {
              final p = raw as Map<String, dynamic>;
              final id = p['id'] as int;
              final priceCents = p['priceCents'] as int? ?? 0;
              final stock = p['stockQuantity'] as int? ?? 0;
              return Div(
                className: 'rounded-xl border border-zinc-800 bg-[#131318] p-5 flex flex-col gap-2',
                children: [
                  H3(className: 'text-white font-semibold', text: p['name'] as String? ?? ''),
                  P(className: 'text-zinc-400 text-sm flex-1', text: p['description'] as String? ?? ''),
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
                    text: 'Add to cart',
                    className: stock > 0
                        ? 'mt-3 px-4 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-medium'
                        : 'mt-3 px-4 py-2 rounded-lg bg-zinc-800 text-zinc-500 text-sm font-medium cursor-not-allowed',
                    onClick: stock > 0 ? (_) => store.addToCart(id) : null,
                  ),
                ],
              );
            }).toList(),
          );
        }),
      ],
    );
  }
}
