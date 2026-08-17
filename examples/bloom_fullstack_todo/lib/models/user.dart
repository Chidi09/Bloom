import 'package:bloom_db/bloom_db.dart';

@BloomModel(app: 'todo', tableName: 'todo_users')
class User extends Model {
  @BloomField(primaryKey: true, auto: true, kind: FieldKind.bigInt)
  final int id;

  @BloomField(unique: true, kind: FieldKind.char, maxLength: 255)
  final String email;

  @BloomField(column: 'password_hash', kind: FieldKind.char, maxLength: 255)
  final String passwordHash;

  @BloomField(kind: FieldKind.char, maxLength: 255)
  final String name;

  @BloomField(column: 'created_at', kind: FieldKind.dateTime)
  final DateTime createdAt;

  User({
    this.id = 0,
    required this.email,
    required this.passwordHash,
    required this.name,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  static const meta = ModelMeta(
    structName: 'User',
    appLabel: 'todo',
    tableName: 'todo_users',
    fields: [
      FieldMeta(
        name: 'id',
        columnName: 'id',
        kind: FieldKind.bigInt,
        primaryKey: true,
        auto: true,
      ),
      FieldMeta(
        name: 'email',
        columnName: 'email',
        kind: FieldKind.char,
        maxLength: 255,
        unique: true,
      ),
      FieldMeta(
        name: 'passwordHash',
        columnName: 'password_hash',
        kind: FieldKind.char,
        maxLength: 255,
      ),
      FieldMeta(
        name: 'name',
        columnName: 'name',
        kind: FieldKind.char,
        maxLength: 255,
      ),
      FieldMeta(
        name: 'createdAt',
        columnName: 'created_at',
        kind: FieldKind.dateTime,
      ),
    ],
    ordering: ['id'],
  );

  @override
  ModelMeta get modelMeta => meta;

  @override
  List<(String, BloomValue)> fieldValues() => [
        ('id', BloomValue.i64(id)),
        ('email', BloomValue.text(email)),
        ('passwordHash', BloomValue.text(passwordHash)),
        ('name', BloomValue.text(name)),
        ('createdAt', BloomValue.dateTime(createdAt)),
      ];

  static User fromRow(DbRow row) {
    return User(
      id: row.tryIntByName('id') ?? 0,
      email: row.tryStringByName('email') ?? '',
      passwordHash: row.tryStringByName('password_hash') ?? '',
      name: row.tryStringByName('name') ?? '',
      createdAt: row.tryDateTimeByName('created_at') ?? DateTime.now().toUtc(),
    );
  }

  static QuerySet<User> objects() {
    return QuerySet<User>(
      meta: meta,
      fromRow: fromRow,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };
}
