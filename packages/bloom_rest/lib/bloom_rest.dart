/// DRF-style (Django REST Framework) REST layer for Bloom on top of `BloomApiRouter` and `bloom_db`.
///
/// Provides generic CRUD-over-a-model ViewSets, field serializers and FieldSets, composable
/// query filter backends, pluggable pagination strategies, composable permissions, and
/// cache-backed rate throttling.
///
/// ```dart
/// import 'package:bloom_cache/bloom_cache.dart';
/// import 'package:bloom_db/bloom_db.dart';
/// import 'package:bloom_framework/bloom_server.dart';
/// import 'package:bloom_rest/bloom_rest.dart';
///
/// void setupRoutes(BloomApiRouter router, DbExecutor db, BloomCache cache) {
///   final serializer = BloomModelSerializer<Article>(
///     meta: Article.meta,
///     fields: BloomFieldSet.all().withReadOnly(['id', 'created_at']),
///   );
///
///   final options = BloomViewSetOptions<Article>(
///     serializer: serializer,
///     pagination: const PageNumberPagination(defaultPageSize: 20),
///     permission: const IsAuthenticated().and(const IsStaff()),
///     throttle: BloomThrottle.fromRate(
///       scope: 'articles_api',
///       rate: '100/hour',
///       cache: cache,
///     ),
///   );
///
///   mountViewSet<Article>(
///     router: router,
///     basePath: '/api/articles',
///     meta: Article.meta,
///     fromRow: Article.fromRow,
///     getDb: (req) => db,
///     options: options,
///   );
/// }
/// ```
library bloom_rest;

export 'src/filters.dart';
export 'src/pagination.dart';
export 'src/permissions.dart';
export 'src/serializers.dart';
export 'src/throttling.dart';
export 'src/viewset.dart';
