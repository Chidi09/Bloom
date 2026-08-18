import 'dart:async';
import 'dart:io';
import 'package:bloom_db/bloom_db.dart';

const ModelMeta _$UserModelMeta = ModelMeta(
  structName: 'User',
  appLabel: 'auth',
  tableName: 'auth_users',
  fields: [
    FieldMeta(
      name: 'id',
      columnName: 'id',
      kind: FieldKind.bigInt,
      nullable: false,
      primaryKey: true,
      auto: true,
      unique: false,
      dbIndex: false,
    ),
    FieldMeta(
      name: 'name',
      columnName: 'name',
      kind: FieldKind.text,
      nullable: false,
      primaryKey: false,
      auto: false,
      unique: false,
      dbIndex: false,
    ),
    FieldMeta(
      name: 'email',
      columnName: 'email',
      kind: FieldKind.text,
      nullable: false,
      primaryKey: false,
      auto: false,
      unique: false,
      dbIndex: false,
    ),
    FieldMeta(
      name: 'age',
      columnName: 'age',
      kind: FieldKind.bigInt,
      nullable: false,
      primaryKey: false,
      auto: false,
      unique: false,
      dbIndex: false,
    ),
    FieldMeta(
      name: 'isActive',
      columnName: 'is_active',
      kind: FieldKind.boolean,
      nullable: false,
      primaryKey: false,
      auto: false,
      unique: false,
      dbIndex: false,
    ),
  ],
  ordering: ['id'],
);

class User with _$UserMixin {
  final int id;
  final String name;
  final String email;
  final int age;
  final bool isActive;

  User({
    this.id = 0,
    required this.name,
    required this.email,
    this.age = 0,
    this.isActive = true,
  });
}

mixin _$UserMixin implements Model {
  int get id;
  String get name;
  String get email;
  int get age;
  bool get isActive;

  @override
  ModelMeta get modelMeta => _$UserModelMeta;

  @override
  List<(String, BloomValue)> fieldValues() => [
        ('id', BloomValue.from(id)),
        ('name', BloomValue.from(name)),
        ('email', BloomValue.from(email)),
        ('age', BloomValue.from(age)),
        ('isActive', BloomValue.from(isActive)),
      ];

  @override
  Map<String, dynamic> toRow() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'age': age,
      'is_active': isActive ? 1 : 0,
    };
  }
}

extension UserOrmExtension on User {
  static ModelMeta meta() => _$UserModelMeta;

  static User fromRow(DbRow row) {
    return User(
      id: row.tryIntByName('id') ?? 0,
      name: row.tryStringByName('name') ?? '',
      email: row.tryStringByName('email') ?? '',
      age: row.tryIntByName('age') ?? 0,
      isActive: row.tryBoolByName('is_active') ?? false,
    );
  }

  static QuerySet<User> objects() {
    return QuerySet<User>(
      meta: _$UserModelMeta,
      fromRow: fromRow,
    );
  }

  Future<void> save(DbExecutor db) async {
    final sql = 'INSERT INTO "auth_users" ("name", "email", "age", "is_active") VALUES (?, ?, ?, ?)';
    await db.execute(sql, [name, email, age, isActive ? 1 : 0]);
  }
}

void main() async {
  final dbPath = '/tmp/bloom_orm_bench.db';
  if (File(dbPath).existsSync()) File(dbPath).deleteSync();

  final db = SqliteDbExecutor.openFile(dbPath);
  await db.execute('PRAGMA synchronous = NORMAL;');
  await db.execute('PRAGMA journal_mode = WAL;');
  await db.execute('''
    CREATE TABLE "auth_users" (
      "id" INTEGER PRIMARY KEY AUTOINCREMENT,
      "name" TEXT NOT NULL,
      "email" TEXT NOT NULL,
      "age" INTEGER NOT NULL,
      "is_active" INTEGER NOT NULL
    );
  ''');

  const insertCount = 5000;
  const lookupCount = 5000;
  const queryCount = 1000;

  print('=== Bloom Native ORM (SQLite) Benchmark ===');

  // 1. Batch / Iterative Inserts
  final swInsert = Stopwatch()..start();
  await db.execute('BEGIN TRANSACTION;');
  for (var i = 1; i <= insertCount; i++) {
    final u = User(
      name: 'User $i',
      email: 'user$i@example.com',
      age: 18 + (i % 60),
      isActive: i % 2 == 0,
    );
    await u.save(db);
  }
  await db.execute('COMMIT;');
  swInsert.stop();
  final insertMs = swInsert.elapsedMilliseconds;
  final insertRps = (insertCount / (insertMs / 1000)).toStringAsFixed(1);
  print('1. Inserts ($insertCount records): ${insertMs}ms ($insertRps ops/sec)');

  // 2. Point Lookups (findById)
  final swLookup = Stopwatch()..start();
  for (var i = 1; i <= lookupCount; i++) {
    final id = 1 + (i % insertCount);
    final user = await UserOrmExtension.objects().filter({'id': id}).first(db);
    assert(user != null);
  }
  swLookup.stop();
  final lookupMs = swLookup.elapsedMilliseconds;
  final lookupRps = (lookupCount / (lookupMs / 1000)).toStringAsFixed(1);
  print('2. Point Lookups ($lookupCount ops): ${lookupMs}ms ($lookupRps ops/sec)');

  // 3. Filtered QuerySet + OrderBy + Limit
  final swQuery = Stopwatch()..start();
  for (var i = 0; i < queryCount; i++) {
    final minAge = 20 + (i % 30);
    final results = await UserOrmExtension.objects()
        .filter({'isActive': true, 'age__gte': minAge})
        .orderBy('-age')
        .limit(20)
        .all(db);
    assert(results.isNotEmpty);
  }
  swQuery.stop();
  final queryMs = swQuery.elapsedMilliseconds;
  final queryRps = (queryCount / (queryMs / 1000)).toStringAsFixed(1);
  print('3. Filtered QuerySet + Pagination ($queryCount queries): ${queryMs}ms ($queryRps ops/sec)');

  // 4. Bulk Update
  final swUpdate = Stopwatch()..start();
  final updatedRows = await UserOrmExtension.objects()
      .filter({'age__gte': 50})
      .update(db, {'isActive': false});
  swUpdate.stop();
  final updateMs = swUpdate.elapsedMilliseconds;
  print('4. Bulk Update ($updatedRows rows updated): ${updateMs}ms');

  await db.close();
}
