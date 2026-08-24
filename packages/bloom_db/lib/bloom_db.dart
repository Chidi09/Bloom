/// First-party database and ORM layer for the Bloom framework.
///
/// Provides Django-inspired declarative models, strongly typed querysets with lazy query compilation,
/// expression filters ([Q], [QF], [F]), and unified database execution across PostgreSQL and SQLite.
///
/// ## Core Subsystems
///
/// - **Declarative Models & Schema Metadata**: Define entity classes annotated with
///   [@BloomModel] and [@BloomField], carrying runtime schema descriptors via [ModelMeta],
///   [FieldMeta], [RelationMeta], and [IndexMeta].
/// - **Lazy Query Compilation ([QuerySet])**: Construct queries immutably with `.filter()`,
///   `.exclude()`, `.orderBy()`, `.limit()`, and `.offset()`. Compile queries to dialect-specific
///   SQL only upon terminal execution (`.all()`, `.get()`, `.first()`, `.count()`, `.exists()`,
///   `.update()`, `.delete()`, `.getOrCreate()`, `.values()`, `.valuesList()`).
/// - **Expressive Filtering & Database Arithmetic ([Q], [QF], [F])**: Compose boolean logic
///   using bitwise operators (`&`, `|`, `~`), lookup suffixes (`__gte`, `__icontains`, `__in`,
///   `__isnull`), field-to-field comparisons ([QF]), and in-database column arithmetic updates ([F]).
/// - **Unified Execution Engine ([DbExecutor])**: Run queries seamlessly against [SqliteDbExecutor]
///   (in-memory or on-disk via `package:sqlite3`) or [PostgresDbExecutor] (via `package:postgres`),
///   with automatic parameter binding and result set mapping to [DbRow] or model instances.
/// - **Multi-Dialect SQL Generators ([Dialect])**: Abstract SQL syntax variances such as
///   placeholders (`$1` vs `?`), case-insensitive matching (`ILIKE` vs `LIKE`), auto-incrementing
///   primary keys (`BIGSERIAL` vs `INTEGER PRIMARY KEY AUTOINCREMENT`), and type casting.
///
/// ## Example: Defining Models and Querying
///
/// ```dart
/// import 'package:bloom_db/bloom_db.dart';
///
/// // 1. Instantiate an in-memory SQLite executor (or PostgresDbExecutor.connect)
/// final db = SqliteDbExecutor.inMemory();
///
/// // 2. Execute DDL migrations or raw SQL
/// await db.execute('''
///   CREATE TABLE "users" (
///     "id" INTEGER PRIMARY KEY AUTOINCREMENT,
///     "name" TEXT NOT NULL,
///     "email" TEXT NOT NULL,
///     "age" INTEGER NOT NULL DEFAULT 0,
///     "is_active" INTEGER NOT NULL DEFAULT 1
///   );
/// ''');
///
/// // 3. Build queries with Q expressions and execute
/// final adults = await QuerySet<User>(
///   meta: User.meta,
///   fromRow: User.fromRow,
/// )
///     .filter(Q('age__gte', 18) & Q('is_active', true))
///     .orderBy('-age')
///     .limit(10)
///     .all(db);
/// ```
library bloom_db;

export 'src/annotations.dart';
export 'src/database.dart';
export 'src/dialect.dart';
export 'src/errors.dart';
export 'src/expr.dart';
export 'src/meta.dart';
export 'src/model.dart';
export 'src/queryset.dart';

