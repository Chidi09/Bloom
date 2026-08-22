import 'package:bloom_auth_server/bloom_auth_server.dart';
import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_rest/bloom_rest.dart';
import 'package:bloom_server/bloom_server.dart';
import 'models/product.dart';
import 'views.dart';

/// Central route registration for the Bloom e-commerce backend, mirroring
/// Django's `urls.py`. Each route maps a path to a handler/ViewSet method
/// defined in `views.dart`, with auth middleware applied per-route.
void registerUrls(
  BloomApiRouter router, {
  required DbExecutor db,
}) {
  // ---------------------------------------------------------------------
  // System routes
  // ---------------------------------------------------------------------
  router.get('/api/health', (req) async {
    return BloomResponse.json({
      'status': 'healthy',
      'service': 'bloom_ecommerce_server',
      'database': 'PostgreSQL connected',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
  });

  // ---------------------------------------------------------------------
  // Auth routes
  // ---------------------------------------------------------------------
  final authHandlers = AuthApiHandlers(db: db);
  router.post('/api/auth/signup', authHandlers.handleSignup);
  router.post('/api/auth/login', authHandlers.handleLogin);
  router.get(
    '/api/auth/me',
    authHandlers.handleMe,
    middlewares: [const BloomAuthMiddleware()],
  );

  // ---------------------------------------------------------------------
  // Product catalog — public reads, staff-only mutations.
  // ---------------------------------------------------------------------
  final productViewSet = BloomViewSet<Product>(
    meta: Product.meta,
    fromRow: Product.fromRow,
    getDb: (_) => db,
    options: BloomViewSetOptions<Product>(
      serializer: BloomModelSerializer<Product>(
        meta: Product.meta,
        fields: BloomFieldSet.all().withReadOnly(['id', 'createdAt']),
      ),
      pagination: const PageNumberPagination(defaultPageSize: 20),
      // Anyone may list/retrieve (safe methods); only staff may
      // create/update/delete products.
      permission: const IsReadOnly() | const IsStaff(),
      config: const BloomViewSetConfig(
        filterableFields: ['name'],
        orderableFields: ['created_at', 'id', 'name', 'price_cents'],
        defaultPageSize: 20,
      ),
    ),
  );
  // Auth is optional here — reads stay public even without a token, but a
  // verified token's roles must be attached to the request for IsStaff to
  // ever grant a mutation (unlike IsAuthenticated below, this middleware
  // does not itself reject unauthenticated requests).
  final optionalAuth = [BloomAuthMiddleware.optional()];
  router.get('/api/products', productViewSet.list, middlewares: optionalAuth);
  router.post('/api/products', productViewSet.create, middlewares: optionalAuth);
  router.get('/api/products/:pk', productViewSet.retrieve, middlewares: optionalAuth);
  router.put('/api/products/:pk', productViewSet.update, middlewares: optionalAuth);
  router.patch('/api/products/:pk', productViewSet.update, middlewares: optionalAuth);
  router.delete('/api/products/:pk', productViewSet.destroy, middlewares: optionalAuth);

  // ---------------------------------------------------------------------
  // Orders — authenticated only.
  // ---------------------------------------------------------------------
  final orderHandlers = OrderApiHandlers(db: db);
  router.post(
    '/api/orders',
    orderHandlers.handleCreateOrder,
    middlewares: [const BloomAuthMiddleware()],
  );
  router.get(
    '/api/orders/mine',
    orderHandlers.handleListMyOrders,
    middlewares: [const BloomAuthMiddleware()],
  );
}
