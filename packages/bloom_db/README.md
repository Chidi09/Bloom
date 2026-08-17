# bloom_db

Core ORM runtime and annotations for the [Bloom framework](https://bloom.dev). A `QuerySet` API
modeled on Django's ORM (and the `djangors-orm` Rust crate this port is based on), supporting both
SQLite and PostgreSQL symmetrically — pick either dialect per environment, not one primary/one
afterthought.

## Features

- `QuerySet<T>` chainable query API: `filter`, `exclude`, `orderBy`, `limit`, `offset`, `get`,
  `first`, `all`, `exists`, `count`, `update`, `delete`, `bulkCreate`, `getOrCreate`,
  `updateOrCreate`, `values`, `valuesList`.
- `Q()` expression objects for composable `&`/`|`/`~` filter conditions, and `F()` for
  field-to-field/field-to-expression updates (e.g. `qty = qty - 1`) without a round-trip read.
- All filter values are bound parameters — never string-interpolated into SQL.
- `save()` is INSERT-only (excludes `auto` fields, uses `RETURNING *`); instance `update()`/
  `delete()` operate by primary key and throw a typed not-found error on zero rows affected.
- `@BloomModel` / `@BloomField` annotations plus a hand-written `ModelMeta` fallback — models can
  be declared either way (see `bloom_db_generator` for the annotation-driven codegen path).
- `PostgresDbExecutor` and `SqliteDbExecutor` — same `QuerySet<T>` code runs unmodified against
  either backend.

## Usage

```dart
import 'package:bloom_db/bloom_db.dart';

@BloomModel(app: 'blog', tableName: 'blog_posts')
class Post extends Model {
  @BloomField(primaryKey: true, auto: true, kind: FieldKind.bigInt)
  final int id;

  @BloomField(kind: FieldKind.char, maxLength: 255)
  final String title;

  Post({this.id = 0, required this.title});

  static final meta = ModelMeta(
    structName: 'Post',
    appLabel: 'blog',
    tableName: 'blog_posts',
    fields: [
      FieldMeta(name: 'id', columnName: 'id', kind: FieldKind.bigInt, primaryKey: true, auto: true),
      FieldMeta(name: 'title', columnName: 'title', kind: FieldKind.char, maxLength: 255),
    ],
  );

  @override
  ModelMeta get modelMeta => meta;

  @override
  List<(String, BloomValue)> fieldValues() => [
        ('id', BloomValue.i64(id)),
        ('title', BloomValue.text(title)),
      ];

  static Post fromRow(DbRow row) => Post(
        id: row.tryIntByName('id') ?? 0,
        title: row.tryStringByName('title') ?? '',
      );

  static QuerySet<Post> objects() => QuerySet<Post>(meta: meta, fromRow: fromRow);
}

final db = await PostgresDbExecutor.connect(
  host: '127.0.0.1',
  port: 5432,
  username: 'postgres',
  password: 'postgres',
  database: 'my_app',
);

final posts = await Post.objects().filter(Q('title__icontains', 'bloom')).orderBy('-id').limit(20).all(db);
```

## Part of Bloom Server

`bloom_db` is one of the packages that make up **Bloom Server**, the backend stack for the Bloom
framework. Scaffold a full project with `bloom server create <name>` (from `bloom_cli`), or see
`examples/bloom_fullstack_todo` in the [Bloom monorepo](https://github.com/bloom-framework/bloom)
for a reference project wiring every Bloom Server package together against real PostgreSQL.

## License

MIT
