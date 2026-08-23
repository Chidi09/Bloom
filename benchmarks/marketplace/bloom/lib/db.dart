import 'package:bloom_db/bloom_db.dart';

DbExecutor? _db;

Future<DbExecutor> getDb() async {
  if (_db != null) return _db!;
  // Env overrides fall back to benchmark defaults
  final host = const String.fromEnvironment('DB_HOST', defaultValue: '127.0.0.1');
  final db = const String.fromEnvironment('DB_NAME', defaultValue: 'marketplace_bench');
  final user = const String.fromEnvironment('DB_USER', defaultValue: 'marketbench');
  final pass = const String.fromEnvironment('DB_PASS', defaultValue: 'marketbench');
  final portStr = const String.fromEnvironment('DB_PORT', defaultValue: '5432');
  final port = int.tryParse(portStr) ?? 5432;
  _db = await PostgresDbExecutor.connect(host: host, database: db, username: user, password: pass, port: port);
  return _db!;
}

// For tests / manual override
void setDb(DbExecutor db) => _db = db;
