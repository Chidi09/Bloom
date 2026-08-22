import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import '../plugins/confetti.dart';
import '../plugins/lucide_icons.dart';
import '../state/store.dart';

class CartComponent {
  final EcommerceStore store;
  final BloomRouterController router;

  CartComponent(this.store, this.router);

  BloomNode build() {
    return Main(
      className: 'max-w-3xl mx-auto px-6 py-10',
      children: [
        H1(className: 'text-2xl font-bold text-white mb-6', text: 'Your cart'),
        Live(() => _buildBody()),
      ],
    );
  }

  BloomNode _buildBody() {
    final cart = store.cart.value;
    if (cart.isEmpty) {
      return P(className: 'text-zinc-400', text: 'Your cart is empty.');
    }

    final rows = <BloomNode>[];
    for (final entry in cart.entries) {
      final product = store.findProduct(entry.key);
      final name = product?['name'] as String? ?? 'Product #${entry.key}';
      final priceCents = product?['priceCents'] as int? ?? 0;
      final quantity = entry.value;

      rows.add(Div(
        className: 'flex items-center justify-between border-b border-zinc-800 py-4',
        children: [
          Div(
            children: [
              P(className: 'text-white font-medium', text: name),
              P(className: 'text-zinc-500 text-sm', text: '\$${(priceCents / 100).toStringAsFixed(2)} each'),
            ],
          ),
          Div(
            className: 'flex items-center gap-3',
            children: [
              Button(
                text: '-',
                className: 'w-8 h-8 rounded-lg bg-zinc-800 hover:bg-zinc-700 text-white',
                onClick: (_) => store.setQuantity(entry.key, quantity - 1),
              ),
              Span(className: 'text-white w-6 text-center', text: '$quantity'),
              Button(
                text: '+',
                className: 'w-8 h-8 rounded-lg bg-zinc-800 hover:bg-zinc-700 text-white',
                onClick: (_) => store.setQuantity(entry.key, quantity + 1),
              ),
              Button(
                className: 'ml-3 text-sm text-red-400 hover:text-red-300 flex items-center gap-1',
                onClick: (_) => store.removeFromCart(entry.key),
                children: [
                  Raw(LucideIcons.svg(LucideIconName.trash2, className: 'w-3.5 h-3.5')),
                  Span(text: 'Remove'),
                ],
              ),
            ],
          ),
        ],
      ));
    }

    return Div(
      children: [
        Div(children: rows),
        Div(
          className: 'flex items-center justify-between mt-6 pt-6 border-t border-zinc-800',
          children: [
            Span(className: 'text-lg text-white font-semibold', text: 'Total'),
            Span(
              className: 'text-lg text-emerald-400 font-bold',
              text: '\$${(store.cartTotalCents / 100).toStringAsFixed(2)}',
            ),
          ],
        ),
        _checkoutButton(),
      ],
    );
  }

  BloomNode _checkoutButton() {
    final mutation = store.checkoutMutation;

    if (!store.isLoggedIn) {
      return Div(
        className: 'mt-6',
        children: [
          P(className: 'text-zinc-400 text-sm mb-2', text: 'Log in to check out.'),
          A(
            text: 'Go to login',
            href: '/login',
            className: 'inline-block px-4 py-2 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-medium',
            onClick: (e) {
              e.preventDefault();
              router.navigate('/login');
            },
          ),
        ],
      );
    }

    return Div(
      className: 'mt-6',
      children: [
        Live(() {
          final err = mutation.error.value;
          if (err == null) return const Fragment(children: []);
          return P(className: 'text-red-400 text-sm mb-2', text: 'Checkout failed: ${describeApiError(err)}');
        }),
        Button(
          text: mutation.isPending ? 'Placing order...' : 'Checkout',
          className: 'px-5 py-2.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white font-medium disabled:opacity-50',
          onClick: mutation.isPending
              ? null
              : (_) async {
                  final items = store.cartAsOrderItems();
                  if (items.isEmpty) return;
                  final result = await mutation.mutate(items);
                  if (result != null) {
                    Confetti.burst();
                    store.clearCart();
                    router.navigate('/');
                  }
                },
        ),
      ],
    );
  }
}
