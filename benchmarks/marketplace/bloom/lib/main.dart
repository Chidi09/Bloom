import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_js_native/browser.dart';
import 'package:web/web.dart' as web;
import 'components/dialog.dart';
import 'components/toast.dart';
import 'pages/admin.dart';
import 'pages/cart.dart';
import 'pages/storefront.dart';

String _resolveApiBaseUrl() {
  final env = BloomEnv.getOrNull('API_BASE_URL') ?? BloomEnv.getOrNull('API_URL');
  if (env != null && env.isNotEmpty) return env;
  try {
    final origin = web.window.location.origin;
    if (origin.isNotEmpty && origin != 'null') return origin;
  } catch (_) {}
  return 'http://localhost:3000';
}

final BloomHttpClient httpClient = BloomHttpClient(baseUrl: _resolveApiBaseUrl());

late final BloomRouterController routerController = BloomRouterController(BloomRouter([
  BloomRoute('/', (params) => homePage(params)),
  BloomRoute('/cart', (params) => cartPage(params)),
  BloomRoute('/p/:slug', (params) => productDetailPage(params)),
  BloomRoute('/c/:slug', (params) => categoryPage(params)),
  BloomRoute('/admin', (params) => adminDashboard(params)),
  BloomRoute('/admin/products', (params) => adminProducts(params)),
  BloomRoute('/admin/products/new', (params) => adminProductNew(params)),
  BloomRoute('/admin/products/:id', (params) => adminProductForm(params)),
], notFound: BloomRoute('/', (params) => homePage(params))));

void main() {
  mount(
    Fragment(children: [
      Live(() => routerController.resolve()),
      dialogViewport(),
      toastViewport(),
    ]),
    '#app',
  );
}

