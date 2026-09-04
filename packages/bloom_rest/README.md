# bloom_rest

DRF-style (Django REST Framework) REST layer for Bloom on top of `BloomApiRouter` and `bloom_db`, modeled on the high-performance `djangors-rest` architecture.

## Features

- **Serializers & FieldSets**: Field-level visibility controls (`read_only`, `write_only`, `only`, `exclude`), automated `BloomModelSerializer` reading `bloom_db` metadata, cross-field validation, and `BloomNestedSerializer`.
  - **Sensitive Field Filtering (Secure by Default)**: Automatically excludes conventionally sensitive fields (`password`, `password_hash`, `token`, `access_token`, `refresh_token`, `secret`, `api_key`) from serialized output and write inputs unless explicitly opted in via `includeSensitiveFields: true`.
- **Pluggable Pagination**:
  - `PageNumberPagination`: `?page=1&page_size=20` with `count`, `total_pages`, `page`, `results`.
  - `LimitOffsetPagination`: `?limit=20&offset=40` with `count`, `limit`, `offset`, `results`.
  - `CursorPagination`: True keyset pagination with opaque base64-encoded cursor (`next_cursor`, `previous_cursor`), honoring `orderingField` with deterministic query ordering and primary-key tie-breaking to guarantee zero pagination drift.
- **Composable Permissions**: Secure by default (`IsAuthenticated`), chainable via `.and()`, `.or()`, and `.negate()`. Includes `AllowAny`, `IsStaff`, `IsSuperuser`, and `IsReadOnly`. Returns `401 Unauthorized` for unauthenticated callers and `403 Forbidden` for authenticated callers denied by permission policies.
- **Throttling & Rate Limiting**:
  - Atomic rate limiting with `BloomAtomicThrottleStore` and `InMemoryAtomicThrottleStore` to prevent get-modify-set race conditions.
  - Header spoofing protection: client forwarding headers (`X-Forwarded-For`, `X-Real-IP`) are only trusted when verified against a `TrustedProxyPredicate` for the immediate transport peer, with a non-spoofable fallback key when peer IP is unavailable.
- **Composable Query Filters**: `BloomFieldFilter` (`?status=active&age__gte=18&tag__in=a,b`), `BloomSearchFilter` (`?search=term`), `BloomOrderingFilter` (`?ordering=-created_at,title`).
- **One-Call ViewSets**: Mount complete REST CRUD routes (`list`, `retrieve`, `create`, `update`, `destroy`) onto `BloomApiRouter`.

---

## Full Worked Example

The following example demonstrates how to create a `BloomViewSet` for an `Article` model with:
1. Field exposure rules (`id` and `created_at` read-only, sensitive fields omitted by default).
2. Keyset `CursorPagination` (or `PageNumberPagination`).
3. Composed permission `IsAuthenticated().and(IsStaff())`.
4. Atomic throttle rate limit (`"100/hour"`).
5. Composable search and field filters.
6. Mounted onto `BloomApiRouter` in a single call.

```dart
import 'package:bloom_cache/bloom_cache.dart';
import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_server/bloom_server.dart';
import 'package:bloom_rest/bloom_rest.dart';

// 1. Define Model
class Article extends Model {
  final int id;
  final String title;
  final String content;
  final String status;
  final DateTime createdAt;

  Article({
    required this.id,
    required this.title,
    required this.content,
    required this.status,
    required this.createdAt,
  });

  static const meta = ModelMeta(
    structName: 'Article',
    appLabel: 'blog',
    tableName: 'articles',
    fields: [
      FieldMeta(name: 'id', columnName: 'id', kind: FieldKind.bigInt, primaryKey: true, auto: true),
      FieldMeta(name: 'title', columnName: 'title', kind: FieldKind.char, maxLength: 255),
      FieldMeta(name: 'content', columnName: 'content', kind: FieldKind.text),
      FieldMeta(name: 'status', columnName: 'status', kind: FieldKind.char, maxLength: 50),
      FieldMeta(name: 'created_at', columnName: 'created_at', kind: FieldKind.dateTime),
    ],
  );

  @override
  ModelMeta get modelMeta => meta;

  @override
  List<(String, BloomValue)> fieldValues() => [
        ('id', BloomValue.i64(id)),
        ('title', BloomValue.text(title)),
        ('content', BloomValue.text(content)),
        ('status', BloomValue.text(status)),
        ('created_at', BloomValue.dateTime(createdAt)),
      ];

  static Article fromRow(DbRow row) {
    return Article(
      id: row.tryIntByName('id') ?? 0,
      title: row.tryStringByName('title') ?? '',
      content: row.tryStringByName('content') ?? '',
      status: row.tryStringByName('status') ?? 'draft',
      createdAt: row.tryDateTimeByName('created_at') ?? DateTime.now(),
    );
  }
}

void main() {
  final router = BloomApiRouter();
  final throttleStore = InMemoryAtomicThrottleStore();
  // Shared database executor factory (e.g. from connection pool)
  late DbExecutor db;

  // 2. Configure Serializer with FieldSet (sensitive fields excluded by default)
  final serializer = BloomModelSerializer<Article>(
    meta: Article.meta,
    fields: BloomFieldSet.all().withReadOnly(['id', 'created_at']),
  );

  // 3. Configure ViewSet Options
  final options = BloomViewSetOptions<Article>(
    serializer: serializer,
    config: const BloomViewSetConfig(
      filterableFields: ['status'],
      orderableFields: ['created_at', 'title', 'id'],
      defaultPageSize: 20,
    ),
    pagination: const CursorPagination(
      defaultPageSize: 20,
      orderingField: 'created_at',
    ),
    // SECURE-BY-DEFAULT: Compose permissions (401 for unauth, 403 for denied)
    permission: const IsAuthenticated().and(const IsStaff()),
    // Atomic rate limiting.
    // IMPORTANT: wire peerExtractor from your server adapter (immediate TCP
    // peer) — without it, all anonymous clients share one global budget and
    // a single aggressive client 429s everyone.
    throttle: BloomThrottle.fromRate(
      scope: 'articles_api',
      rate: '100/hour',
      atomicStore: throttleStore,
      keyStrategy: ByUserOrIp(
        peerExtractor: (req) => req.params['tcp_peer'],
      ),
    ),
    filterBackends: [
      const BloomSearchFilter<Article>(['title', 'content']),
      const BloomOrderingFilter<Article>(['created_at', 'title']),
    ],
  );

  // 4. Mount CRUD routes onto BloomApiRouter in one call
  mountViewSet<Article>(
    router: router,
    basePath: '/api/articles',
    meta: Article.meta,
    fromRow: Article.fromRow,
    getDb: (req) => db,
    options: options,
  );

  // Mounted endpoints:
  // GET    /api/articles          -> list (paginated, filtered, throttled, guarded)
  // POST   /api/articles          -> create (validated, throttled, guarded)
  // GET    /api/articles/:pk      -> retrieve
  // PUT    /api/articles/:pk      -> update (full)
  // PATCH  /api/articles/:pk      -> update (partial)
  // DELETE /api/articles/:pk      -> destroy
}

```
