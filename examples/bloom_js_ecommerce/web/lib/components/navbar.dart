import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import '../state/store.dart';

class NavbarComponent {
  final EcommerceStore store;
  final BloomRouterController router;

  NavbarComponent(this.store, this.router);

  BloomNode build() {
    return Header(
      className: 'flex items-center justify-between px-6 py-4 border-b border-zinc-800 bg-[#111116]',
      children: [
        A(
          text: 'Bloom Store',
          href: '/',
          className: 'text-lg font-bold text-white cursor-pointer',
          onClick: (e) {
            e.preventDefault();
            router.navigate('/');
          },
        ),
        Nav(
          className: 'flex items-center gap-5',
          children: [
            A(
              text: 'Cart',
              href: '/cart',
              className: 'text-sm text-zinc-300 hover:text-white flex items-center gap-1',
              onClick: (e) {
                e.preventDefault();
                router.navigate('/cart');
              },
              children: [
                Live(() {
                  final count = store.cartItemCount;
                  if (count == 0) return const Fragment(children: []);
                  return Span(
                    className: 'ml-1 inline-flex items-center justify-center text-xs font-semibold bg-indigo-600 text-white rounded-full w-5 h-5',
                    text: '$count',
                  );
                }),
              ],
            ),
            Live(() {
              if (store.isLoggedIn) {
                final user = store.currentUser.value;
                return Div(
                  className: 'flex items-center gap-3',
                  children: [
                    Span(
                      className: 'text-sm text-zinc-400',
                      text: user?['name'] as String? ?? 'Account',
                    ),
                    Button(
                      text: 'Log out',
                      className: 'text-sm px-3 py-1.5 rounded-lg bg-zinc-800 hover:bg-zinc-700 text-zinc-200',
                      onClick: (_) {
                        store.logout();
                        router.navigate('/');
                      },
                    ),
                  ],
                );
              }
              return A(
                text: 'Log in',
                href: '/login',
                className: 'text-sm px-3 py-1.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white',
                onClick: (e) {
                  e.preventDefault();
                  router.navigate('/login');
                },
              );
            }),
          ],
        ),
      ],
    );
  }
}
