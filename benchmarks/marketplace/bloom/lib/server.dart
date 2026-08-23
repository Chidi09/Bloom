import 'dart:io';
import 'package:bloom_server/bloom_server.dart';
import 'api/routes.dart';

BloomApiRouter buildRouter() {
  final router = BloomApiRouter();

  // JSON API — lean, load-tested tier
  router.get('/api/products', (req) async => listProductsHandler(req));
  router.get('/api/products/:slug', (req) async => singleProductHandler(req));
  router.get('/api/products/:slug/images', (req) async => productImagesHandler(req));
  router.get('/api/categories/:slug', (req) async => singleCategoryHandler(req));
  router.get('/api/admin/products', (req) async => adminListProductsHandler(req));
  router.get('/api/admin/products/:id', (req) async => adminSingleProductHandler(req));
  router.get('/api/admin/stats', (req) async => adminStatsHandler(req));

  // Static asset fallback for client bundle (if present)
  router.get('/main.js', (req) async {
    final file = File('web/main.js');
    if (await file.exists()) return BloomResponse.file(file, contentType: 'application/javascript');
    return BloomResponse.notFound('Not found');
  });

  return router;
}
