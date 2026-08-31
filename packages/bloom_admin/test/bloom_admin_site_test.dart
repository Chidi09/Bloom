import 'dart:convert';
import 'package:test/test.dart';
import 'package:bloom_db/bloom_db.dart';
import 'package:bloom_server/bloom_server.dart';
import 'package:bloom_admin/bloom_admin.dart';

class Article extends Model {
  final int id;
  final String title;
  final String content;
  final bool isPublished;

  Article({
    required this.id,
    required this.title,
    required this.content,
    required this.isPublished,
  });

  static const meta = ModelMeta(
    structName: 'Article',
    appLabel: 'blog',
    tableName: 'articles',
    fields: [
      FieldMeta(
        name: 'id',
        columnName: 'id',
        kind: FieldKind.integer,
        primaryKey: true,
        auto: true,
      ),
      FieldMeta(
        name: 'title',
        columnName: 'title',
        kind: FieldKind.char,
        maxLength: 255,
      ),
      FieldMeta(
        name: 'content',
        columnName: 'content',
        kind: FieldKind.text,
      ),
      FieldMeta(
        name: 'is_published',
        columnName: 'is_published',
        kind: FieldKind.boolean,
      ),
    ],
  );

  @override
  ModelMeta get modelMeta => meta;

  @override
  List<(String, BloomValue)> fieldValues() => [
        ('id', BloomValue.i64(id)),
        ('title', BloomValue.text(title)),
        ('content', BloomValue.text(content)),
        ('is_published', BloomValue.boolVal(isPublished)),
      ];

  static Article fromRow(DbRow row) {
    return Article(
      id: row.tryIntByName('id') ?? 0,
      title: row.tryStringByName('title') ?? '',
      content: row.tryStringByName('content') ?? '',
      isPublished: row.tryBoolByName('is_published') ?? false,
    );
  }
}

void main() {
  late DbExecutor db;
  late BloomApiRouter router;
  late BloomAdminSite adminSite;

  setUp(() async {
    db = SqliteDbExecutor.inMemory();
    await db.execute('''
      CREATE TABLE articles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        is_published INTEGER NOT NULL
      )
    ''');

    router = BloomApiRouter();
    adminSite = BloomAdminSite();
    adminSite.register<Article>(
      meta: Article.meta,
      fromRow: Article.fromRow,
      config: const BloomModelAdminConfig(
        listDisplay: ['id', 'title', 'is_published'],
        searchFields: ['title', 'content'],
        listFilter: ['is_published'],
        listEditable: ['title'],
      ),
    );
    adminSite.mount(router, db: db, basePath: '/admin');
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedData() async {
    for (var i = 1; i <= 5; i++) {
      await db.execute(
        'INSERT INTO articles (title, content, is_published) VALUES (?, ?, ?)',
        ['Article $i', 'Body of $i', i.isEven ? 1 : 0],
      );
    }
  }

  test(
      'GET /admin/ renders Bloom Console dashboard index with registered models',
      () async {
    final req = BloomRequest(
      method: 'GET',
      uri: Uri.parse('http://localhost/admin/'),
      headers: {},
    );

    final res = await router.handle(req);
    expect(res.statusCode, equals(200));
    final body = utf8.decode(res.body);
    expect(body, contains('Bloom Console'));
    expect(body, contains('blog.Article'));
    expect(body, contains('console-grid'));
    expect(body, contains('console-card'));
  });

  test('GET /admin/blog/article/ renders changelist table with seed records',
      () async {
    await seedData();

    final req = BloomRequest(
      method: 'GET',
      uri: Uri.parse('http://localhost/admin/blog/article/'),
      headers: {},
    );

    final res = await router.handle(req);
    expect(res.statusCode, equals(200));
    final body = utf8.decode(res.body);
    expect(body, contains('Article 1'));
    expect(body, contains('Article 2'));
    expect(body, contains('console-table'));
    expect(body, contains('action-toggle'));
    expect(body, contains('Export CSV'));
  });

  test('GET /admin/blog/article/export-csv/ exports CSV attachment', () async {
    await seedData();

    final req = BloomRequest(
      method: 'GET',
      uri: Uri.parse('http://localhost/admin/blog/article/export-csv/'),
      headers: {},
    );

    final res = await router.handle(req);
    expect(res.statusCode, equals(200));
    expect(res.headers['content-type'], contains('text/csv'));
    expect(res.headers['content-disposition'], contains('article.csv'));
    final csv = utf8.decode(res.body);
    expect(csv, contains('id,title,is_published'));
    expect(csv, contains('Article 1'));
  });

  test(
      'GET /admin/blog/article/add/ and POST /admin/blog/article/add/ creates a new record',
      () async {
    final csrfToken = adminSite.csrf.generateToken();

    // GET add form
    final getReq = BloomRequest(
      method: 'GET',
      uri: Uri.parse('http://localhost/admin/blog/article/add/'),
      headers: {},
    );
    final getRes = await router.handle(getReq);
    expect(getRes.statusCode, equals(200));
    expect(utf8.decode(getRes.body), contains('title'));

    // POST add form
    final postBody =
        'csrfmiddlewaretoken=$csrfToken&title=New+Article&content=New+Content&is_published=on';
    final postReq = BloomRequest(
      method: 'POST',
      uri: Uri.parse('http://localhost/admin/blog/article/add/'),
      headers: {'content-type': 'application/x-www-form-urlencoded'},
      body: postBody,
    );

    final postRes = await router.handle(postReq);
    expect(postRes.statusCode, equals(302));
    expect(postRes.headers['location'], equals('/blog/article/'));

    final rows = await db
        .fetchAll('SELECT * FROM articles WHERE title = ?', ['New Article']);
    expect(rows.length, equals(1));
    expect(rows.first.tryStringByName('content'), equals('New Content'));
  });

  test('GET and POST /admin/blog/article/:pk/change/ updates record', () async {
    await seedData();
    final csrfToken = adminSite.csrf.generateToken();

    final changeReq = BloomRequest(
      method: 'GET',
      uri: Uri.parse('http://localhost/admin/blog/article/1/change/'),
      headers: {},
    );
    final changeRes = await router.handle(changeReq);
    expect(changeRes.statusCode, equals(200));
    expect(utf8.decode(changeRes.body), contains('Article 1'));

    final postBody =
        'csrfmiddlewaretoken=$csrfToken&title=Updated+Article+1&content=Updated+Content&is_published=1';
    final postReq = BloomRequest(
      method: 'POST',
      uri: Uri.parse('http://localhost/admin/blog/article/1/change/'),
      headers: {'content-type': 'application/x-www-form-urlencoded'},
      body: postBody,
    );
    final postRes = await router.handle(postReq);
    expect(postRes.statusCode, equals(302));

    final updated = await db.fetchAll('SELECT * FROM articles WHERE id = 1');
    expect(updated.first.tryStringByName('title'), equals('Updated Article 1'));
  });

  test('GET and POST /admin/blog/article/:pk/delete/ removes record', () async {
    await seedData();
    final csrfToken = adminSite.csrf.generateToken();

    final deleteGetReq = BloomRequest(
      method: 'GET',
      uri: Uri.parse('http://localhost/admin/blog/article/2/delete/'),
      headers: {},
    );
    final deleteGetRes = await router.handle(deleteGetReq);
    expect(deleteGetRes.statusCode, equals(200));
    expect(utf8.decode(deleteGetRes.body), contains('Confirm Deletion'));

    final deletePostReq = BloomRequest(
      method: 'POST',
      uri: Uri.parse('http://localhost/admin/blog/article/2/delete/'),
      headers: {'content-type': 'application/x-www-form-urlencoded'},
      body: 'csrfmiddlewaretoken=$csrfToken',
    );
    final deletePostRes = await router.handle(deletePostReq);
    expect(deletePostRes.statusCode, equals(302));

    final check = await db.fetchAll('SELECT * FROM articles WHERE id = 2');
    expect(check, isEmpty);
  });
}
