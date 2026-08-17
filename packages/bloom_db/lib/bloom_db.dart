/// First-party database and ORM layer for the Bloom framework.
///
/// Provides Django-inspired declarative models, strongly typed querysets with lazy query compilation,
/// expression filters ([Q], [QF], [F]), and unified database execution across PostgreSQL and SQLite.
///
/// Example:
/// ```dart
/// import 'package:bloom_db/bloom_db.dart';
///
/// void main() async {
///   final db = SqliteDbExecutor.inMemory();
///
///   // Create table
///   await db.execute('''
///     CREATE TABLE "auth_users" (
///       "id" INTEGER PRIMARY KEY AUTOINCREMENT,
///       "name" TEXT NOT NULL,
///       "email" TEXT NOT NULL,
///       "age" INTEGER NOT NULL DEFAULT 0,
///       "is_active" INTEGER NOT NULL DEFAULT 1
///     );
///   ''');
///
///   // Query using expressions
///   final users = await User.objects()
///       .filter(Q('age__gte', 18) & Q('isActive', true))
///       .orderBy('-age')
///       .all(db);
/// }
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

