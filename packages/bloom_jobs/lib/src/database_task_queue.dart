// lib/src/database_task_queue.dart
import 'dart:async';
import 'dart:convert';
import 'package:bloom_db/bloom_db.dart';
import 'queue.dart';
import 'task.dart';

/// A database-backed [BloomTaskQueue] implementation that persists background jobs
/// in a SQL database table using Bloom's unified [DbExecutor] abstraction.
///
/// Works with both PostgreSQL ([PostgresDbExecutor]) and SQLite ([SqliteDbExecutor]).
///
/// ### Concurrency, Leases, and Atomic Claiming
/// - **PostgreSQL**: Uses `UPDATE ... WHERE id = (SELECT id FROM ... FOR UPDATE SKIP LOCKED) RETURNING ...`
///   guaranteeing zero contention and lock-free concurrency across any number of workers.
/// - **SQLite**: Uses a single atomic `UPDATE ... WHERE id = (SELECT id FROM ... LIMIT 1) AND status = 'pending' RETURNING ...`
///   ensuring atomic claiming and race detection via affected returned rows.
/// - **Durability & Leases**: Generated ownership tokens and lease expiration timestamps protect tasks from
///   stale completions, with expired running leases atomically reclaimed before pending work.
class DatabaseTaskQueue extends BloomTaskQueue {
  /// The underlying database executor from `package:bloom_db`.
  final DbExecutor db;

  /// The table name where queued tasks are persisted.
  final String tableName;

  @override
  final Duration defaultLeaseDuration;

  bool _initialized = false;
  int _idSeq = 0;

  /// Creates a [DatabaseTaskQueue] using the provided [db] executor.
  ///
  /// Parameters:
  /// - [db]: Database executor connected to PostgreSQL or SQLite.
  /// - [tableName]: Custom table name for task records. Defaults to `'bloom_queued_tasks'`.
  /// - [defaultLeaseDuration]: Default lease duration for claimed tasks. Defaults to 5 minutes.
  DatabaseTaskQueue(
    this.db, {
    this.tableName = 'bloom_queued_tasks',
    this.defaultLeaseDuration = BloomTaskQueue.standardLeaseDuration,
  }) : super.base();

  /// Idempotently ensures that the task queue table and performance indices exist.
  ///
  /// Callers or database migration runners should invoke this before first use.
  Future<void> ensureSchema() async {
    if (_initialized) return;

    final timestampType = db.dialect.timestampType;
    final sql = 'CREATE TABLE IF NOT EXISTS $tableName ('
        'id TEXT PRIMARY KEY, '
        'task_name TEXT NOT NULL, '
        'payload TEXT NOT NULL, '
        'status TEXT NOT NULL, '
        'created_at $timestampType NOT NULL, '
        'scheduled_at $timestampType NOT NULL, '
        'started_at $timestampType, '
        'finished_at $timestampType, '
        'attempts INTEGER NOT NULL DEFAULT 0, '
        'max_attempts INTEGER NOT NULL DEFAULT 3, '
        'last_error TEXT, '
        'last_stack_trace TEXT, '
        'token TEXT, '
        'lease_expires_at $timestampType'
        ')';
    await db.execute(sql);

    // Ensure columns exist on pre-existing tables
    try {
      await db.execute('ALTER TABLE $tableName ADD COLUMN token TEXT');
    } catch (_) {}
    try {
      await db.execute(
        'ALTER TABLE $tableName ADD COLUMN lease_expires_at $timestampType',
      );
    } catch (_) {}

    await db.execute(
      'CREATE INDEX IF NOT EXISTS ${tableName}_status_scheduled_idx '
      'ON $tableName (status, scheduled_at)',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS ${tableName}_status_lease_idx '
      'ON $tableName (status, lease_expires_at)',
    );

    _initialized = true;
  }

  String _generateId() {
    _idSeq++;
    return '${DateTime.now().microsecondsSinceEpoch}_$_idSeq';
  }

  String _generateToken() {
    _idSeq++;
    return 'tok_${DateTime.now().microsecondsSinceEpoch}_$_idSeq';
  }

  BloomQueuedTask _rowToTask(DbRow row) {
    final id = row.tryStringByName('id') ?? row['id'].toString();
    final taskName =
        row.tryStringByName('task_name') ?? row['task_name'] as String;

    final rawPayload = row.tryStringByName('payload') ?? row['payload'];
    final Map<String, dynamic> payload;
    if (rawPayload is String) {
      final decoded = jsonDecode(rawPayload);
      payload = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } else if (rawPayload is Map) {
      payload = Map<String, dynamic>.from(rawPayload);
    } else {
      payload = <String, dynamic>{};
    }

    final statusStr = row.tryStringByName('status') ?? row['status'].toString();
    final status = BloomTaskStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => BloomTaskStatus.pending,
    );

    final createdAt = row.tryDateTimeByName('created_at') ??
        (row['created_at'] is DateTime
            ? row['created_at'] as DateTime
            : DateTime.parse(row['created_at'].toString()));

    final scheduledAt = row.tryDateTimeByName('scheduled_at') ??
        (row['scheduled_at'] is DateTime
            ? row['scheduled_at'] as DateTime
            : DateTime.parse(row['scheduled_at'].toString()));

    final startedAt = row.tryDateTimeByName('started_at') ??
        (row['started_at'] != null
            ? (row['started_at'] is DateTime
                ? row['started_at'] as DateTime
                : DateTime.tryParse(row['started_at'].toString()))
            : null);

    final finishedAt = row.tryDateTimeByName('finished_at') ??
        (row['finished_at'] != null
            ? (row['finished_at'] is DateTime
                ? row['finished_at'] as DateTime
                : DateTime.tryParse(row['finished_at'].toString()))
            : null);

    final attempts =
        row.tryIntByName('attempts') ?? (row['attempts'] as num).toInt();
    final maxAttempts = row.tryIntByName('max_attempts') ??
        (row['max_attempts'] as num).toInt();
    final lastError =
        row.tryStringByName('last_error') ?? row['last_error']?.toString();
    final lastStackTrace = row.tryStringByName('last_stack_trace') ??
        row['last_stack_trace']?.toString();
    final token = row.tryStringByName('token') ?? row['token']?.toString();
    final leaseExpiresAt = row.tryDateTimeByName('lease_expires_at') ??
        (row['lease_expires_at'] != null
            ? (row['lease_expires_at'] is DateTime
                ? row['lease_expires_at'] as DateTime
                : DateTime.tryParse(row['lease_expires_at'].toString()))
            : null);

    return BloomQueuedTask(
      id: id,
      taskName: taskName,
      payload: payload,
      status: status,
      createdAt: createdAt,
      scheduledAt: scheduledAt,
      attempts: attempts,
      maxAttempts: maxAttempts,
      token: token,
      leaseExpiresAt: leaseExpiresAt,
      lastError: lastError,
      lastStackTrace: lastStackTrace,
      startedAt: startedAt,
      finishedAt: finishedAt,
    );
  }

  @override
  Future<BloomQueuedTask> enqueueScheduled(
    String taskName,
    Map<String, dynamic> payload,
    DateTime runAt, {
    int maxAttempts = 3,
  }) async {
    await ensureSchema();
    final id = _generateId();
    final now = DateTime.now().toUtc();
    final scheduled = runAt.toUtc();
    final payloadJson = jsonEncode(payload);

    final p = db.dialect.placeholder;
    final sql = 'INSERT INTO $tableName ('
        'id, task_name, payload, status, created_at, scheduled_at, attempts, max_attempts'
        ') VALUES (${p(1)}, ${p(2)}, ${p(3)}, ${p(4)}, ${p(5)}, ${p(6)}, ${p(7)}, ${p(8)})';

    await db.execute(sql, [
      id,
      taskName,
      payloadJson,
      BloomTaskStatus.pending.name,
      now,
      scheduled,
      0,
      maxAttempts,
    ]);

    return BloomQueuedTask(
      id: id,
      taskName: taskName,
      payload: Map<String, dynamic>.from(payload),
      status: BloomTaskStatus.pending,
      createdAt: now,
      scheduledAt: scheduled,
      attempts: 0,
      maxAttempts: maxAttempts,
    );
  }

  @override
  Future<BloomQueuedTask?> claimNext(
      [DateTime? now, Duration? leaseDuration]) async {
    await ensureSchema();
    final refTime = (now ?? DateTime.now()).toUtc();
    final effectiveLease = leaseDuration ?? defaultLeaseDuration;
    final leaseExpiresAt = refTime.add(effectiveLease);
    final token = _generateToken();
    final p = db.dialect.placeholder;

    // 1. Atomically reclaim expired running leases before claiming pending work
    // 1a. Fail tasks whose running lease expired and have exhausted max_attempts
    final failExpiredSql = 'UPDATE $tableName '
        'SET status = ${p(1)}, '
        '    finished_at = ${p(2)}, '
        '    last_error = CASE WHEN last_error IS NULL THEN ${p(3)} ELSE last_error END, '
        '    token = NULL, '
        '    lease_expires_at = NULL '
        'WHERE status = ${p(4)} AND lease_expires_at <= ${p(5)} AND attempts >= max_attempts';
    await db.execute(failExpiredSql, [
      BloomTaskStatus.failed.name,
      refTime,
      'Task lease expired',
      BloomTaskStatus.running.name,
      refTime,
    ]);

    // 1b. Requeue tasks whose running lease expired and still have attempts remaining
    final reclaimPendingSql = 'UPDATE $tableName '
        'SET status = ${p(1)}, '
        '    scheduled_at = ${p(2)}, '
        '    token = NULL, '
        '    lease_expires_at = NULL '
        'WHERE status = ${p(3)} AND lease_expires_at <= ${p(4)} AND attempts < max_attempts';
    await db.execute(reclaimPendingSql, [
      BloomTaskStatus.pending.name,
      refTime,
      BloomTaskStatus.running.name,
      refTime,
    ]);

    // 2. Atomically claim next pending, due task
    final List<DbRow> rows;
    if (db.dialect.type == DialectType.postgres) {
      final sql = 'UPDATE $tableName '
          'SET status = ${p(1)}, '
          '    attempts = attempts + 1, '
          '    started_at = ${p(2)}, '
          '    token = ${p(3)}, '
          '    lease_expires_at = ${p(4)} '
          'WHERE id = ('
          '  SELECT id FROM $tableName '
          '  WHERE status = ${p(5)} AND scheduled_at <= ${p(6)} '
          '  ORDER BY scheduled_at ASC, id ASC '
          '  LIMIT 1 '
          '  FOR UPDATE SKIP LOCKED'
          ') AND status = ${p(5)} '
          'RETURNING id, task_name, payload, status, created_at, scheduled_at, '
          'started_at, finished_at, attempts, max_attempts, last_error, last_stack_trace, '
          'token, lease_expires_at';

      rows = await db.fetchAll(sql, [
        BloomTaskStatus.running.name,
        refTime,
        token,
        leaseExpiresAt,
        BloomTaskStatus.pending.name,
        refTime,
      ]);
    } else {
      // SQLite: single UPDATE with WHERE subquery and status='pending' guard
      final sql = 'UPDATE $tableName '
          'SET status = ?, '
          '    attempts = attempts + 1, '
          '    started_at = ?, '
          '    token = ?, '
          '    lease_expires_at = ? '
          'WHERE id = ('
          '  SELECT id FROM $tableName '
          '  WHERE status = ? AND scheduled_at <= ? '
          '  ORDER BY scheduled_at ASC, id ASC '
          '  LIMIT 1'
          ') AND status = ? '
          'RETURNING id, task_name, payload, status, created_at, scheduled_at, '
          'started_at, finished_at, attempts, max_attempts, last_error, last_stack_trace, '
          'token, lease_expires_at';

      rows = await db.fetchAll(sql, [
        BloomTaskStatus.running.name,
        refTime,
        token,
        leaseExpiresAt,
        BloomTaskStatus.pending.name,
        refTime,
        BloomTaskStatus.pending.name,
      ]);
    }

    if (rows.isEmpty) {
      return null;
    }

    return _rowToTask(rows.first);
  }

  @override
  Future<void> markCompleted(String taskId, {String? token}) async {
    await ensureSchema();
    if (token == null || token.isEmpty) {
      throw StateError(
        'Task with id "$taskId" cannot be marked completed: invalid or missing token.',
      );
    }

    final p = db.dialect.placeholder;
    final now = DateTime.now().toUtc();
    final sql = 'UPDATE $tableName '
        'SET status = ${p(1)}, '
        '    last_error = NULL, '
        '    last_stack_trace = NULL, '
        '    finished_at = ${p(2)}, '
        '    token = NULL, '
        '    lease_expires_at = NULL '
        'WHERE id = ${p(3)} AND token = ${p(4)} AND status = ${p(5)}';

    final affected = await db.execute(sql, [
      BloomTaskStatus.succeeded.name,
      now,
      taskId,
      token,
      BloomTaskStatus.running.name,
    ]);

    if (affected == 0) {
      throw StateError(
        'Task with id "$taskId" cannot be marked completed: not found, not running, or token mismatch.',
      );
    }
  }

  @override
  Future<void> markFailed(
    String taskId, {
    String? token,
    required String errorMessage,
    String? stackTrace,
    DateTime? retryAfter,
  }) async {
    await ensureSchema();
    if (token == null || token.isEmpty) {
      throw StateError(
        'Task with id "$taskId" cannot be marked failed: invalid or missing token.',
      );
    }

    final p = db.dialect.placeholder;
    final fetchSql = 'SELECT id, attempts, max_attempts '
        'FROM $tableName '
        'WHERE id = ${p(1)} AND token = ${p(2)} AND status = ${p(3)}';
    final row = await db.fetchOptional(fetchSql, [
      taskId,
      token,
      BloomTaskStatus.running.name,
    ]);

    if (row == null) {
      throw StateError(
        'Task with id "$taskId" cannot be marked failed: not found, not running, or token mismatch.',
      );
    }

    final attempts =
        row.tryIntByName('attempts') ?? (row['attempts'] as num).toInt();
    final maxAttempts = row.tryIntByName('max_attempts') ??
        (row['max_attempts'] as num).toInt();
    final now = DateTime.now().toUtc();

    if (attempts < maxAttempts) {
      final effectiveRetryAfter = retryAfter?.toUtc() ??
          now.add(Duration(seconds: (1 << attempts).clamp(1, 60)));

      final sql = 'UPDATE $tableName '
          'SET status = ${p(1)}, '
          '    scheduled_at = ${p(2)}, '
          '    last_error = ${p(3)}, '
          '    last_stack_trace = ${p(4)}, '
          '    finished_at = ${p(5)}, '
          '    token = NULL, '
          '    lease_expires_at = NULL '
          'WHERE id = ${p(6)} AND token = ${p(7)} AND status = ${p(8)}';

      final affected = await db.execute(sql, [
        BloomTaskStatus.pending.name,
        effectiveRetryAfter,
        errorMessage,
        stackTrace,
        now,
        taskId,
        token,
        BloomTaskStatus.running.name,
      ]);

      if (affected == 0) {
        throw StateError(
          'Task with id "$taskId" cannot be marked failed: not found, not running, or token mismatch.',
        );
      }
    } else {
      final sql = 'UPDATE $tableName '
          'SET status = ${p(1)}, '
          '    last_error = ${p(2)}, '
          '    last_stack_trace = ${p(3)}, '
          '    finished_at = ${p(4)}, '
          '    token = NULL, '
          '    lease_expires_at = NULL '
          'WHERE id = ${p(5)} AND token = ${p(6)} AND status = ${p(7)}';

      final affected = await db.execute(sql, [
        BloomTaskStatus.failed.name,
        errorMessage,
        stackTrace,
        now,
        taskId,
        token,
        BloomTaskStatus.running.name,
      ]);

      if (affected == 0) {
        throw StateError(
          'Task with id "$taskId" cannot be marked failed: not found, not running, or token mismatch.',
        );
      }
    }
  }

  @override
  Future<List<BloomQueuedTask>> allTasks() async {
    await ensureSchema();
    final sql =
        'SELECT id, task_name, payload, status, created_at, scheduled_at, '
        'started_at, finished_at, attempts, max_attempts, last_error, last_stack_trace, '
        'token, lease_expires_at '
        'FROM $tableName ORDER BY scheduled_at ASC, id ASC';
    final rows = await db.fetchAll(sql);
    return List<BloomQueuedTask>.unmodifiable(rows.map(_rowToTask));
  }

  @override
  Future<BloomQueuedTask?> getTask(String id) async {
    await ensureSchema();
    final p1 = db.dialect.placeholder(1);
    final sql =
        'SELECT id, task_name, payload, status, created_at, scheduled_at, '
        'started_at, finished_at, attempts, max_attempts, last_error, last_stack_trace, '
        'token, lease_expires_at '
        'FROM $tableName WHERE id = $p1';
    final row = await db.fetchOptional(sql, [id]);
    if (row == null) return null;
    return _rowToTask(row);
  }

  @override
  Future<void> clear() async {
    await ensureSchema();
    await db.execute('DELETE FROM $tableName');
  }
}
