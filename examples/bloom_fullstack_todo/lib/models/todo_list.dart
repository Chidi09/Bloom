import 'package:bloom_db/bloom_db.dart';
import 'user.dart';

@BloomModel(app: 'todo', tableName: 'todo_lists')
class TodoList extends Model {
  @BloomField(primaryKey: true, auto: true, kind: FieldKind.bigInt)
  final int id;

  @BloomField(kind: FieldKind.char, maxLength: 255)
  final String name;

  @BloomField(column: 'owner_id', kind: FieldKind.bigInt)
  final int ownerId;

  @BloomField(column: 'created_at', kind: FieldKind.dateTime)
  final DateTime createdAt;

  TodoList({
    this.id = 0,
    required this.name,
    required this.ownerId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  static final meta = ModelMeta(
    structName: 'TodoList',
    appLabel: 'todo',
    tableName: 'todo_lists',
    fields: [
      FieldMeta(
        name: 'id',
        columnName: 'id',
        kind: FieldKind.bigInt,
        primaryKey: true,
        auto: true,
      ),
      FieldMeta(
        name: 'name',
        columnName: 'name',
        kind: FieldKind.char,
        maxLength: 255,
      ),
      FieldMeta(
        name: 'ownerId',
        columnName: 'owner_id',
        kind: FieldKind.bigInt,
      ),
      FieldMeta(
        name: 'createdAt',
        columnName: 'created_at',
        kind: FieldKind.dateTime,
      ),
    ],
    relations: [
      RelationMeta(
        fieldName: 'ownerId',
        kind: RelationKind.foreignKey,
        target: () => User.meta,
        onDelete: OnDelete.cascade,
      ),
    ],
    ordering: ['-createdAt', 'id'],
  );

  @override
  ModelMeta get modelMeta => meta;

  @override
  List<(String, BloomValue)> fieldValues() => [
        ('id', BloomValue.i64(id)),
        ('name', BloomValue.text(name)),
        ('ownerId', BloomValue.i64(ownerId)),
        ('createdAt', BloomValue.dateTime(createdAt)),
      ];

  static TodoList fromRow(DbRow row) {
    return TodoList(
      id: row.tryIntByName('id') ?? 0,
      name: row.tryStringByName('name') ?? '',
      ownerId: row.tryIntByName('owner_id') ?? 0,
      createdAt: row.tryDateTimeByName('created_at') ?? DateTime.now().toUtc(),
    );
  }

  static QuerySet<TodoList> objects() {
    return QuerySet<TodoList>(
      meta: meta,
      fromRow: fromRow,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ownerId': ownerId,
        'createdAt': createdAt.toIso8601String(),
      };
}
