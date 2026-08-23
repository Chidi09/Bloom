import 'package:bloom_js_native/bloom_js_native.dart';
import '../components/button_variants.dart';
import '../components/dialog.dart';
import '../components/layout.dart';
import '../components/ui.dart';
import '../state/cart.dart';

BloomNode cartPage(Map<String, String> params) {
  return appShell(
    Div(
      className: 'max-w-4xl mx-auto',
      children: [
        H1(className: 'text-h1 mb-6', text: 'Shopping Cart'),
        Live(() => _cartContent()),
      ],
    ),
  );
}

BloomNode _cartContent() {
  final items = cart.value.values.toList();
  if (items.isEmpty) {
    return emptyState(
      icon: 'shopping',
      title: 'Your cart is empty',
      description:
          'Looks like you haven\'t added anything to your cart yet. Explore our curated goods and find something you love.',
      action: button(text: 'Explore collection', variant: ButtonVariant.primary, href: '/'),
    );
  }

  return Div(
    className: 'grid lg:grid-cols-3 gap-8 items-start',
    children: [
      // Cart items list
      Div(
        className: 'lg:col-span-2 flex flex-col gap-4',
        children: [
          Div(
            className: 'flex items-center justify-between pb-2 border-b border-[var(--border)]',
            children: [
              Span(className: 'text-sm text-[var(--text-muted)]', text: '${cartItemCount} ${cartItemCount == 1 ? 'item' : 'items'} in cart'),
              El('button',
                attrs: {'type': 'button'},
                className: 'text-xs text-[var(--text-muted)] hover:text-[var(--danger)] hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)] rounded px-1',
                onClick: (_) => openConfirmDialog(
                  title: 'Clear cart?',
                  description: 'This will remove all $cartItemCount items from your cart. This cannot be undone.',
                  confirmLabel: 'Clear cart',
                  destructive: true,
                  onConfirm: () => clearCart(),
                ),
                children: [Span(text: 'Clear cart')],
              ),
            ],
          ),
          ...items.map((item) => _cartLineItem(item)),
        ],
      ),
      // Summary / Checkout card
      Div(
        className: 'rounded-[10px] border border-[var(--border)] bg-[var(--card)] p-6 shadow-sm flex flex-col gap-4 sticky top-20',
        children: [
          H3(className: 'text-h3 border-b border-[var(--border)] pb-3', text: 'Order Summary'),
          Div(className: 'flex justify-between text-sm', children: [
            Span(className: 'text-[var(--text-muted)]', text: 'Subtotal (${cartItemCount} items)'),
            priceText(cartTotalCents),
          ]),
          Div(className: 'flex justify-between text-sm', children: [
            Span(className: 'text-[var(--text-muted)]', text: 'Shipping'),
            Span(className: 'text-[var(--text-muted)]', text: 'Calculated at checkout'),
          ]),
          Div(className: 'flex justify-between text-base font-semibold border-t border-[var(--border)] pt-3 mt-1', children: [
            Span(text: 'Total'),
            priceText(cartTotalCents),
          ]),
          Div(className: 'mt-2 flex flex-col gap-1.5', children: [
            button(
              text: 'Checkout',
              variant: ButtonVariant.primary,
              attrs: {'disabled': ''},
              extraClassName: 'w-full py-3 opacity-60 cursor-not-allowed',
            ),
            P(
              className: 'text-xs text-center text-[var(--text-muted)]',
              text: "Checkout isn't available in this demo yet",
            ),
          ]),
        ],
      ),
    ],
  );
}

BloomNode _cartLineItem(CartItem item) {
  final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;
  return Div(
    className: 'rounded-[10px] border border-[var(--border)] bg-[var(--card)] p-4 flex flex-col sm:flex-row gap-4 items-start sm:items-center justify-between',
    children: [
      Div(className: 'flex gap-4 items-center flex-1 min-w-0', children: [
        if (hasImage)
          Link(
            href: '/p/${item.slug}',
            className: 'shrink-0',
            children: [
              bloomImage(
                src: item.imageUrl!,
                alt: item.title,
                widths: [160, 320],
                sizes: '80px',
                className: 'w-20 h-20 object-cover rounded-md border border-[var(--border)] bg-[var(--bg-muted)]',
              ),
            ],
          )
        else
          Div(
            className: 'w-20 h-20 rounded-md bg-[var(--bg-muted)] border border-[var(--border)] shrink-0 grid place-items-center text-xs text-[var(--text-muted)]',
            text: 'No image',
          ),
        Div(className: 'flex flex-col gap-1 min-w-0 flex-1', children: [
          Link(
            href: '/p/${item.slug}',
            className: 'font-medium text-sm sm:text-base hover:underline text-[var(--text)] line-clamp-2',
            text: item.title,
          ),
          Div(className: 'flex items-baseline gap-2 text-xs sm:text-sm text-[var(--text-muted)]', children: [
            Span(text: 'Unit price:'),
            priceText(item.priceCents),
          ]),
        ]),
      ]),
      Div(className: 'flex sm:flex-col items-center sm:items-end justify-between w-full sm:w-auto gap-3 pt-2 sm:pt-0 border-t sm:border-t-0 border-[var(--border)]', children: [
        Div(className: 'flex items-center gap-1', children: [
          El('button',
            attrs: {'type': 'button', 'aria-label': 'Decrease quantity of ${item.title}'},
            className: 'w-7 h-7 rounded-md border border-[var(--border)] bg-[var(--bg-muted)] hover:bg-[var(--border)] text-[var(--text)] flex items-center justify-center text-sm font-bold focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)] select-none',
            onClick: (_) => setCartQuantity(item.id, item.quantity - 1),
            children: [Span(text: '−')],
          ),
          Span(className: 'w-8 text-center text-sm font-semibold tabular', text: '${item.quantity}'),
          El('button',
            attrs: {'type': 'button', 'aria-label': 'Increase quantity of ${item.title}'},
            className: 'w-7 h-7 rounded-md border border-[var(--border)] bg-[var(--bg-muted)] hover:bg-[var(--border)] text-[var(--text)] flex items-center justify-center text-sm font-bold focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--brand-600)] select-none',
            onClick: (_) => setCartQuantity(item.id, item.quantity + 1),
            children: [Span(text: '+')],
          ),
        ]),
        Div(className: 'flex items-center gap-3', children: [
          Span(className: 'text-sm font-semibold price tabular', text: '\$${((item.priceCents * item.quantity) / 100).toStringAsFixed(2)}'),
          El('button',
            attrs: {'type': 'button', 'aria-label': 'Remove ${item.title} from cart'},
            className: 'inline-flex items-center gap-1 px-2 py-1 rounded text-xs font-medium text-[var(--danger)] hover:bg-[var(--danger)]/10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--danger)] transition-colors',
            onClick: (_) => removeFromCart(item.id),
            children: [
              hugeIcon('archive', className: 'w-3.5 h-3.5'),
              Span(text: 'Remove'),
            ],
          ),
        ]),
      ]),
    ],
  );
}
