import 'dart:io';
import 'package:bloom_js_native/bloom_js_native.dart';
import 'package:bloom_server/bloom_server.dart';
import 'api/routes.dart';
import 'design/tokens.dart';
import 'pages/admin.dart';
import 'pages/storefront.dart';

String _wrap(String bodyHtml, {String title = 'Marketplace — Bloom Benchmark'}) {
  return '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(title)}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@500;600;700&family=Inter:wght@400;500;600&display=swap" rel="stylesheet">
<script type="importmap">{"imports":{"@tailwindcss/browser":"https://esm.sh/@tailwindcss/browser@4.3.3?bundle"}}</script>
<script type="module">import "@tailwindcss/browser";</script>
<style>${designTokensCss}</style>
</head>
<body>
$bodyHtml
</body>
</html>''';
}

BloomApiRouter buildRouter() {
  final router = BloomApiRouter();

  // JSON API — lean, load-tested tier
  router.get('/api/products', (req) async => listProductsHandler(req));
  router.get('/api/products/:slug', (req) async => singleProductHandler(req));

  // Storefront SSR
  router.get('/', (req) async {
    final node = await homePage(req);
    return BloomResponse.html(_wrap(renderToHtml(node)));
  });
  router.get('/p/:slug', (req) async {
    final node = await productDetailPage(req);
    return BloomResponse.html(_wrap(renderToHtml(node), title: 'Product — Marketplace'));
  });
  router.get('/c/:slug', (req) async {
    final node = await categoryPage(req);
    return BloomResponse.html(_wrap(renderToHtml(node)));
  });

  // Admin SSR (no auth — TODO Stage 2)
  router.get('/admin', (req) async {
    final node = await adminDashboard(req);
    return BloomResponse.html(_wrap(renderToHtml(node), title: 'Admin — Marketplace'));
  });
  router.get('/admin/products', (req) async {
    final node = await adminProducts(req);
    return BloomResponse.html(_wrap(renderToHtml(node), title: 'Admin Products — Marketplace'));
  });
  router.get('/admin/products/new', (req) async {
    final node = await adminProductForm(req, isNew: true);
    return BloomResponse.html(_wrap(renderToHtml(node), title: 'New Product — Admin'));
  });
  router.get('/admin/products/:id', (req) async {
    final node = await adminProductForm(req, isNew: false);
    return BloomResponse.html(_wrap(renderToHtml(node), title: 'Edit Product — Admin'));
  });

  // Static asset fallback for client bundle (if present)
  router.get('/main.js', (req) async {
    final file = File('web/main.js');
    if (await file.exists()) return BloomResponse.file(file, contentType: 'application/javascript');
    return BloomResponse.notFound('Not found');
  });

  return router;
}
