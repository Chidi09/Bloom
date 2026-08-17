import 'package:bloom_db/bloom_db.dart';
import 'todo_list.dart';

@BloomModel(app: 'todo', tableName: 'todo_tasks')
class TodoTask extends Model {
  @BloomField(primaryKey: true, auto: true, kind: FieldKind.bigInt)
  final int id;

  @BloomField(column: 'list_id', kind: FieldKind.bigInt)
  final int listId;

  @BloomField(kind: FieldKind.char, maxLength: 255)
  final String title;

  @BloomField(kind: FieldKind.boolean)
  final bool done;

  @BloomField(column: 'created_at', kind: FieldKind.dateTime)
  final DateTime createdAt;

  TodoTask({
    this.id = 0,
    required this.listId,
    required this.title,
    this.done = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  static final meta = ModelMeta(
    structName: 'TodoTask',
    appLabel: 'todo',
    tableName: 'todo_tasks',
    fields: [
      FieldMeta(
        name: 'id',
        columnName: 'id',
        kind: FieldKind.bigInt,
        primaryKey: true,
        auto: true,
      ),
      FieldMeta(
        name: 'listId',
        columnName: 'list_id',
        kind: FieldKind.bigInt,
      ),
      FieldMeta(
        name: 'title',
        columnName: 'title',
        kind: FieldKind.char,
        maxLength: 255,
      ),
      FieldMeta(
        name: 'done',
        columnName: 'done',
        kind: FieldKind.boolean,
      ),
      FieldMeta(
        name: 'createdAt',
        columnName: 'created_at',
        kind: FieldKind.dateTime,
      ),
    ],
    relations: [
      RelationMeta(
        fieldName: 'listId',
        kind: RelationKind.foreignKey,
        target: () => TodoList.meta,
        onDelete: OnDelete.cascade,
      ),
    ],
    ordering: ['id'],
  );

  @override
  ModelMeta get modelMeta => meta;

  @override
  List<(String, BloomValue)> fieldValues() => [
        ('id', BloomValue.i64(id)),
        ('listId', BloomValue.i64(listId)),
        ('title', BloomValue.text(title)),
        ('done', BloomValue.boolVal(done)),
        ('createdAt', BloomValue.dateTime(createdAt)),
      ];

  static TodoTask fromRow(DbRow row) {
    return TodoTask(
      id: row.tryIntByName('id') ?? 0,
      listId: row.tryIntByName('list_id') ?? 0,
      title: row.tryStringByName('title') ?? '',
      done: row.tryBoolByName('done') ?? false,
      createdAt: row.tryDateTimeByName('created_at') ?? DateTime.now().toUtc(),
    );
  }

  static QuerySet<TodoTask> objects() {
    return QuerySet<TodoTask>(
      meta: meta,
      fromRow: fromRow,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'listId': listId,
        'title': title,
        'done': done,
        'createdAt': createdAt.toIso8601String(),
      };
}
