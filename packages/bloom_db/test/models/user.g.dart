// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// ModelGenerator
// **************************************************************************

// **************************************************************************
// BloomModelGenerator
// **************************************************************************

/// Static metadata for [User].
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

/// Generated ORM mixin for [User].
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
    final values = fieldValues();
    final meta = modelMeta;
    final map = <String, dynamic>{};
    for (final (fieldName, val) in values) {
      final f = meta.findField(fieldName);
      final colName = f != null ? f.columnName : fieldName;
      map[colName] = val.raw;
    }
    return map;
  }
}

/// Generated extension providing ORM operations for [User].
extension UserOrmExtension on User {
  /// Static accessor for [User] metadata.
  static ModelMeta meta() => _$UserModelMeta;

  /// Every field's name in declaration order.
  static List<String> fieldNames() => [
        'id',
        'name',
        'email',
        'age',
        'isActive',
      ];

  /// Constructs a [User] instance from a [DbRow].
  static User fromRow(DbRow row) {
    return User(
      id: row.tryIntByName('id') ?? 0,
      name: row.tryStringByName('name') ?? '',
      email: row.tryStringByName('email') ?? '',
      age: row.tryIntByName('age') ?? 0,
      isActive: row.tryBoolByName('is_active') ?? false,
    );
  }

  /// Creates a new [QuerySet] for [User].
  static QuerySet<User> objects() {
    return QuerySet<User>(
      meta: _$UserModelMeta,
      fromRow: fromRow,
    );
  }

  /// Saves a new record into the database (INSERT-only).
  ///
  /// Fields with `auto: true` are excluded from the column list.
  /// Uses `RETURNING *` and returns a NEW [User] instance populated from the inserted database row.
  Future<User> save(DbExecutor db) async {
    final dialect = db.dialect;
    final saveCols = <String>['name', 'email', 'age', 'is_active'];
    final placeholders = <String>[];
    final params = <dynamic>[];
    var paramIdx = 1;

    final valuesMap = {for (final (k, v) in fieldValues()) k: v.raw};
    for (final col in saveCols) {
      final f = _$UserModelMeta.findField(col)!;
      placeholders.add(dialect.placeholder(paramIdx++));
      params.add(valuesMap[f.name]);
    }

    final colsQuoted = saveCols.map((c) => '"$c"').join(', ');
    final sql = saveCols.isEmpty
        ? 'INSERT INTO "auth_users" DEFAULT VALUES RETURNING *'
        : 'INSERT INTO "auth_users" ($colsQuoted) VALUES (${placeholders.join(', ')}) RETURNING *';

    final row = await db.fetchOne(sql, params);
    return fromRow(row);
  }

  /// Updates the database record matching this instance's primary key.
  ///
  /// Sets every non-primary-key column to the current instance values.
  /// Throws [BloomOrmNotFoundError] if no row was updated (0 affected rows).
  Future<void> update(DbExecutor db) async {
    final dialect = db.dialect;
    final updateFields = <FieldMeta>[
      _$UserModelMeta.findField('name')!,
      _$UserModelMeta.findField('email')!,
      _$UserModelMeta.findField('age')!,
      _$UserModelMeta.findField('isActive')!
    ];

    final setClauses = <String>[];
    final params = <dynamic>[];
    var paramIdx = 1;

    final valuesMap = {for (final (k, v) in fieldValues()) k: v.raw};
    for (final f in updateFields) {
      setClauses.add('"${f.columnName}" = ${dialect.placeholder(paramIdx++)}');
      params.add(valuesMap[f.name]);
    }

    final pkPlaceholder = dialect.placeholder(paramIdx++);
    params.add(id);

    final sql =
        'UPDATE "auth_users" SET ${setClauses.join(', ')} WHERE "id" = $pkPlaceholder';
    final rowsAffected = await db.execute(sql, params);
    if (rowsAffected == 0) {
      throw BloomOrmNotFoundError(model: 'User');
    }
  }

  /// Deletes the database record matching this instance's primary key.
  ///
  /// Throws [BloomOrmNotFoundError] if no row was deleted (0 affected rows).
  Future<void> delete(DbExecutor db) async {
    final dialect = db.dialect;
    final pkPlaceholder = dialect.placeholder(1);
    final sql = 'DELETE FROM "auth_users" WHERE "id" = $pkPlaceholder';
    final rowsAffected = await db.execute(sql, [id]);
    if (rowsAffected == 0) {
      throw BloomOrmNotFoundError(model: 'User');
    }
  }
}
