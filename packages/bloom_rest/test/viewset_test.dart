import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_server/bloom_server.dart';
import 'package:bloom_rest/bloom_rest.dart';
import 'package:test/test.dart';

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
      FieldMeta(
          name: 'id',
          columnName: 'id',
          kind: FieldKind.bigInt,
          primaryKey: true,
          auto: true),
      FieldMeta(
          name: 'title',
          columnName: 'title',
          kind: FieldKind.char,
          maxLength: 255),
      FieldMeta(name: 'content', columnName: 'content', kind: FieldKind.text),
      FieldMeta(
          name: 'status',
          columnName: 'status',
          kind: FieldKind.char,
          maxLength: 50),
      FieldMeta(
          name: 'created_at',
          columnName: 'created_at',
          kind: FieldKind.dateTime),
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

/// Test permission allowing only even-id rows at the object level (#5).
class _EvenIdOnly extends BloomRestPermission {
  const _EvenIdOnly();

  @override
  bool hasPermission(BloomRequest req) => true;

  @override
  bool hasObjectPermission(BloomRequest req, Object item) {
    return (item as Article).id.isEven;
  }
}

void main() {
  late DbExecutor db;

  setUp(() async {
    db = SqliteDbExecutor.inMemory();
    await db.execute('''
      CREATE TABLE articles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedArticles() async {
    final fixedTime = DateTime.utc(2026, 8, 20, 10, 0, 0);
    for (var i = 1; i <= 10; i++) {
      // Intentionally share timestamp for some rows to test deterministic PK tie-breaker
      final timestamp = fixedTime.add(Duration(days: i ~/ 3));
      await db.execute(
        'INSERT INTO articles (title, content, status, created_at) VALUES (?, ?, ?, ?)',
        [
          'Article $i',
          'Content for article $i',
          i.isEven ? 'published' : 'draft',
          timestamp.toIso8601String()
        ],
      );
    }
  }

  group('BloomViewSet CRUD Operations', () {
    test('list, retrieve, create, update, and destroy with mounted routes',
        () async {
      await seedArticles();

      final router = BloomApiRouter();
      final viewSet = BloomViewSet<Article>(
        meta: Article.meta,
        fromRow: Article.fromRow,
        getDb: (_) => db,
        options: BloomViewSetOptions<Article>(
          permission: const AllowAny(),
          serializer: BloomModelSerializer<Article>(
            meta: Article.meta,
            fields: BloomFieldSet.all().withReadOnly(['id']),
          ),
          config: const BloomViewSetConfig(
            filterableFields: ['status'],
            orderableFields: ['created_at', 'id', 'title'],
            defaultPageSize: 5,
          ),
          pagination: const PageNumberPagination(defaultPageSize: 5),
          filterBackends: [
            const BloomSearchFilter<Article>(['title', 'content']),
            const BloomOrderingFilter<Article>(['created_at', 'title', 'id']),
          ],
        ),
      );
      viewSet.mount(router, '/api/articles');

      // 1. LIST (GET /api/articles)
      final listReq = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/api/articles?status=published&page=1'),
      );
      final listRes = await viewSet.list(listReq);
      expect(listRes.statusCode, 200);
      final listJson = listRes.bodyJson as Map<String, dynamic>;
      expect(listJson['count'], 5); // 5 published articles out of 10
      expect((listJson['results'] as List).length, 5);

      // 2. RETRIEVE (GET /api/articles/:pk)
      final getReq = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/api/articles/1'),
        params: {'pk': '1'},
      );
      final getRes = await viewSet.retrieve(getReq);
      expect(getRes.statusCode, 200);
      final getJson = getRes.bodyJson as Map<String, dynamic>;
      expect(getJson['id'], 1);
      expect(getJson['title'], 'Article 1');

      // 3. CREATE (POST /api/articles)
      final postReq = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost/api/articles'),
        body: {
          'title': 'New Article',
          'content': 'Fresh content',
          'status': 'published',
          'created_at': '2026-08-31T20:00:00Z',
        },
      );
      final postRes = await viewSet.create(postReq);
      expect(postRes.statusCode, 201);
      final postJson = postRes.bodyJson as Map<String, dynamic>;
      expect(postJson['id'], 11);
      expect(postJson['title'], 'New Article');

      // 4. UPDATE (PATCH /api/articles/:pk)
      final patchReq = BloomRequest(
        method: 'PATCH',
        uri: Uri.parse('http://localhost/api/articles/11'),
        params: {'pk': '11'},
        body: {'title': 'Updated Title'},
      );
      final patchRes = await viewSet.update(patchReq);
      expect(patchRes.statusCode, 200);
      final patchJson = patchRes.bodyJson as Map<String, dynamic>;
      expect(patchJson['title'], 'Updated Title');
      expect(patchJson['status'], 'published');

      // 5. DESTROY (DELETE /api/articles/:pk)
      final deleteReq = BloomRequest(
        method: 'DELETE',
        uri: Uri.parse('http://localhost/api/articles/11'),
        params: {'pk': '11'},
      );
      final deleteRes = await viewSet.destroy(deleteReq);
      expect(deleteRes.statusCode, 204);

      // Verify 404 after deletion
      final getDeletedRes =
          await viewSet.retrieve(getReq.copyWith(params: {'pk': '11'}));
      expect(getDeletedRes.statusCode, 404);
    });

    group('object-level authorization (#5)', () {
      BloomViewSet<Article> evenOnlyViewSet() {
        return BloomViewSet<Article>(
          meta: Article.meta,
          fromRow: Article.fromRow,
          getDb: (_) => db,
          options: BloomViewSetOptions<Article>(
            permission: const _EvenIdOnly(),
            serializer: BloomModelSerializer<Article>(
              meta: Article.meta,
              fields: BloomFieldSet.all().withReadOnly(['id']),
            ),
          ),
        );
      }

      BloomRequest pkReq(String method, String pk,
          {Map<String, dynamic>? body}) {
        return BloomRequest(
          method: method,
          uri: Uri.parse('http://localhost/api/articles/$pk'),
          params: {'pk': pk},
          body: body,
        );
      }

      test('denied objects return 404 on retrieve/update/destroy', () async {
        await seedArticles();
        final viewSet = evenOnlyViewSet();

        // retrieve: odd id denied -> 404, even id allowed -> 200
        expect((await viewSet.retrieve(pkReq('GET', '1'))).statusCode, 404);
        expect((await viewSet.retrieve(pkReq('GET', '2'))).statusCode, 200);

        // update: denied -> 404 and row unchanged
        final deniedUpdate = await viewSet.update(
            pkReq('PATCH', '1', body: {'title': 'Hacked'}));
        expect(deniedUpdate.statusCode, 404);
        final allowedViewSet = BloomViewSet<Article>(
          meta: Article.meta,
          fromRow: Article.fromRow,
          getDb: (_) => db,
          options: BloomViewSetOptions<Article>(
            permission: const AllowAny(),
            serializer: BloomModelSerializer<Article>(meta: Article.meta),
          ),
        );
        final check = await allowedViewSet.retrieve(pkReq('GET', '1'));
        expect(check.statusCode, 200);
        expect(
            (check.bodyJson as Map<String, dynamic>)['title'], 'Article 1');

        // allowed update still works
        final okUpdate = await viewSet.update(
            pkReq('PATCH', '2', body: {'title': 'Edited'}));
        expect(okUpdate.statusCode, 200);

        // destroy: denied -> 404 and row still exists
        expect((await viewSet.destroy(pkReq('DELETE', '3'))).statusCode, 404);
        expect((await allowedViewSet.retrieve(pkReq('GET', '3'))).statusCode,
            200);
      });
    });

    test('returns 422 on invalid model creation input', () async {
      final viewSet = BloomViewSet<Article>(
        meta: Article.meta,
        fromRow: Article.fromRow,
        getDb: (_) => db,
        options: BloomViewSetOptions<Article>(
          permission: const AllowAny(),
          serializer: BloomModelSerializer<Article>(
            meta: Article.meta,
            fields: BloomFieldSet.all().withReadOnly(['id']),
          ),
        ),
      );

      final req = BloomRequest(
        method: 'POST',
        uri: Uri.parse('http://localhost/api/articles'),
        body: {
          'title': 'Incomplete Article',
          // missing 'content', 'status', 'created_at'
        },
      );

      final res = await viewSet.create(req);
      expect(res.statusCode, 422);
      final body = res.bodyJson as Map<String, dynamic>;
      expect(body['errors'], isNotNull);
    });
  });

  group('Permission Enforcement: 401 Unauthorized vs 403 Forbidden', () {
    late BloomViewSet<Article> viewSet;

    setUp(() {
      viewSet = BloomViewSet<Article>(
        meta: Article.meta,
        fromRow: Article.fromRow,
        getDb: (_) => db,
        options: BloomViewSetOptions<Article>(
          permission: const IsStaff(),
          serializer: BloomModelSerializer<Article>(meta: Article.meta),
        ),
      );
    });

    test('returns 401 Unauthorized when request has no verified identity',
        () async {
      final unauthReq = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/api/articles'),
      );

      final res = await viewSet.list(unauthReq);
      expect(res.statusCode, 401);
      final json = res.bodyJson as Map<String, dynamic>;
      expect(json['error'],
          contains('Authentication credentials were not provided'));
    });

    test(
        'returns 403 Forbidden when request is authenticated but denied by permission policy',
        () async {
      final forbiddenReq = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/api/articles'),
        params: {
          'auth_user_id': 'user_123',
          'auth_roles': 'viewer', // Does not have 'staff' or 'admin'
        },
      );

      final res = await viewSet.list(forbiddenReq);
      expect(res.statusCode, 403);
      final json = res.bodyJson as Map<String, dynamic>;
      expect(json['error'], contains('Permission denied'));
    });

    test('allows access when authenticated request satisfies permission policy',
        () async {
      final staffReq = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/api/articles'),
        params: {
          'auth_user_id': 'staff_99',
          'auth_roles': 'staff',
        },
      );

      final res = await viewSet.list(staffReq);
      expect(res.statusCode, 200);
    });
  });

  group('Throttling in ViewSet', () {
    test('returns 429 Too Many Requests when rate limit is exceeded', () async {
      final store = InMemoryAtomicThrottleStore();
      final throttle = BloomThrottle(
        scope: 'articles_api',
        maxRequests: 2,
        window: const Duration(minutes: 1),
        atomicStore: store,
      );

      final viewSet = BloomViewSet<Article>(
        meta: Article.meta,
        fromRow: Article.fromRow,
        getDb: (_) => db,
        options: BloomViewSetOptions<Article>(
          permission: const AllowAny(),
          serializer: BloomModelSerializer<Article>(meta: Article.meta),
          throttle: throttle,
        ),
      );

      final req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/api/articles'),
        params: {'peer_ip': '10.0.0.5'},
      );

      expect((await viewSet.list(req)).statusCode, 200);
      expect((await viewSet.list(req)).statusCode, 200);
      final throttledRes = await viewSet.list(req);
      expect(throttledRes.statusCode, 429);
      expect(throttledRes.bodyJson['error'], 'Too Many Requests');
    });
  });

  group(
      'Cursor Pagination Regression: Deterministic Ordering & Stable Next-Page',
      () {
    test(
        'honors CursorPagination.orderingField and traverses pages stably with tie-breaking',
        () async {
      await seedArticles();

      final viewSet = BloomViewSet<Article>(
        meta: Article.meta,
        fromRow: Article.fromRow,
        getDb: (_) => db,
        options: BloomViewSetOptions<Article>(
          permission: const AllowAny(),
          serializer: BloomModelSerializer<Article>(meta: Article.meta),
          config: const BloomViewSetConfig(
            orderableFields: ['created_at', 'id'],
          ),
          pagination: const CursorPagination(
            defaultPageSize: 3,
            orderingField: 'created_at',
          ),
        ),
      );

      // Page 1
      final page1Req = BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/api/articles'),
      );
      final page1Res = await viewSet.list(page1Req);
      expect(page1Res.statusCode, 200);
      final page1Json = page1Res.bodyJson as Map<String, dynamic>;
      final page1Results =
          (page1Json['results'] as List).cast<Map<String, dynamic>>();
      expect(page1Results.length, 3);
      final nextCursor1 = page1Json['next_cursor'] as String?;
      expect(nextCursor1, isNotNull);

      final page1Ids = page1Results.map((r) => r['id'] as int).toList();

      // Page 2 using next_cursor
      final page2Req = BloomRequest(
        method: 'GET',
        uri: Uri.parse(
            'http://localhost/api/articles?cursor=${Uri.encodeComponent(nextCursor1!)}'),
      );
      final page2Res = await viewSet.list(page2Req);
      expect(page2Res.statusCode, 200);
      final page2Json = page2Res.bodyJson as Map<String, dynamic>;
      final page2Results =
          (page2Json['results'] as List).cast<Map<String, dynamic>>();
      expect(page2Results.length, 3);
      final nextCursor2 = page2Json['next_cursor'] as String?;
      expect(nextCursor2, isNotNull);

      final page2Ids = page2Results.map((r) => r['id'] as int).toList();

      // Ensure zero overlap between page 1 and page 2 despite identical timestamps on seed records
      final overlap = page1Ids.toSet().intersection(page2Ids.toSet());
      expect(overlap, isEmpty,
          reason: 'Page 1 and Page 2 should have no overlapping IDs');

      // Page 3 using next_cursor
      final page3Req = BloomRequest(
        method: 'GET',
        uri: Uri.parse(
            'http://localhost/api/articles?cursor=${Uri.encodeComponent(nextCursor2!)}'),
      );
      final page3Res = await viewSet.list(page3Req);
      expect(page3Res.statusCode, 200);
      final page3Json = page3Res.bodyJson as Map<String, dynamic>;
      final page3Results =
          (page3Json['results'] as List).cast<Map<String, dynamic>>();
      expect(page3Results.length, 3);
      final nextCursor3 = page3Json['next_cursor'] as String?;
      expect(nextCursor3, isNotNull);

      final page3Ids = page3Results.map((r) => r['id'] as int).toList();
      expect(page1Ids.toSet().intersection(page3Ids.toSet()), isEmpty);
      expect(page2Ids.toSet().intersection(page3Ids.toSet()), isEmpty);

      // Page 4 (final 1 item out of 10)
      final page4Req = BloomRequest(
        method: 'GET',
        uri: Uri.parse(
            'http://localhost/api/articles?cursor=${Uri.encodeComponent(nextCursor3!)}'),
      );
      final page4Res = await viewSet.list(page4Req);
      expect(page4Res.statusCode, 200);
      final page4Json = page4Res.bodyJson as Map<String, dynamic>;
      final page4Results =
          (page4Json['results'] as List).cast<Map<String, dynamic>>();
      expect(page4Results.length, 1);
      // No more pages
      expect(page4Json['next_cursor'], isNull);
    });

    test('descending cursor pagination (-id) navigates in reverse order stably',
        () async {
      await seedArticles();

      final viewSet = BloomViewSet<Article>(
        meta: Article.meta,
        fromRow: Article.fromRow,
        getDb: (_) => db,
        options: BloomViewSetOptions<Article>(
          permission: const AllowAny(),
          serializer: BloomModelSerializer<Article>(meta: Article.meta),
          pagination: const CursorPagination(
            defaultPageSize: 4,
            orderingField: '-id',
          ),
        ),
      );

      final p1Res = await viewSet.list(BloomRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/api/articles'),
      ));
      final p1Json = p1Res.bodyJson as Map<String, dynamic>;
      final p1Results =
          (p1Json['results'] as List).cast<Map<String, dynamic>>();
      expect(p1Results.map((r) => r['id']), [10, 9, 8, 7]);
      final cursor = p1Json['next_cursor'] as String;

      final p2Res = await viewSet.list(BloomRequest(
        method: 'GET',
        uri: Uri.parse(
            'http://localhost/api/articles?cursor=${Uri.encodeComponent(cursor)}'),
      ));
      final p2Json = p2Res.bodyJson as Map<String, dynamic>;
      final p2Results =
          (p2Json['results'] as List).cast<Map<String, dynamic>>();
      expect(p2Results.map((r) => r['id']), [6, 5, 4, 3]);
    });
  });
}
