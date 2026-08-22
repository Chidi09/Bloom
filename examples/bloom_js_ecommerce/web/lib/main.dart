import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';

import 'components/auth.dart';
import 'components/cart.dart';
import 'components/navbar.dart';
import 'components/product_grid.dart';
import 'state/store.dart';

final _store = EcommerceStore.instance;

/// The client-side router controller — a top-level late final so route
/// builders (which close over it to call `.navigate()`) and `main()` can
/// both reference the same instance.
late final BloomRouterController routerController = BloomRouterController(BloomRouter([
  BloomRoute('/', (params) => ProductGridComponent(_store).build()),
  BloomRoute('/cart', (params) => CartComponent(_store, routerController).build()),
  BloomRoute('/login', (params) => AuthComponent(_store, routerController).build()),
], notFound: BloomRoute('/', (params) => ProductGridComponent(_store).build())));

void main() {
  final app = Div(
    className: 'min-h-screen flex flex-col',
    children: [
      Live(() => NavbarComponent(_store, routerController).build()),
      Live(() => routerController.resolve()),
    ],
  );

  mount(app, '#app');
}
