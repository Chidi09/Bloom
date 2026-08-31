// lib/src/redis_task_queue.dart
import 'dart:async';
import 'dart:convert';
import 'package:redis/redis.dart';
import 'queue.dart';
import 'task.dart';

/// A distributed [BloomTaskQueue] implementation backed by Redis via `package:redis`.
///
/// ### Key Architecture
/// - **Cross-Process Atomic Task Claiming**: Uses an atomic Redis Lua script (`EVAL`)
///   evaluating `ZRANGEBYSCORE` on the scheduled-tasks sorted set, claiming and removing
///   the due task in a single atomic transaction. Multiple worker processes or isolates
///   cannot double-claim the same job.
/// - **Durability & Leases**: Generated ownership tokens and lease expiration timestamps protect tasks from
///   stale completions, with expired running leases atomically reclaimed before pending work.
/// - **Scheduled / Delayed Jobs**: Due timestamps are indexed in a Redis ZSET
///   keyed by epoch milliseconds for O(log N) scheduling and due-task retrieval.
/// - **JSON Serialization**: Full task metadata round-trips as JSON strings in Redis.
/// - **Prefix Namespacing**: Optional [prefix] prepended to all Redis keys
///   preventing collisions in multi-tenant or shared Redis instances.
/// - **Lazy Connection**: Connects to Redis lazily upon first command execution.
class RedisTaskQueue extends BloomTaskQueue {
  /// The Redis server hostname.
  final String host;

  /// The Redis server port.
  final int port;

  /// Optional authentication password (`AUTH`).
  final String? password;

  /// Optional database numerical index (`SELECT`).
  final int? db;

  /// Whether to connect using TLS/SSL (`rediss://`).
  final bool secure;

  /// Optional key prefix prepended to all task keys and sets.
  final String prefix;

  @override
  final Duration defaultLeaseDuration;

  RedisConnection? _connection;
  Command? _command;
  int _tokenSeq = 0;

  /// Creates a [RedisTaskQueue] with explicit connection parameters.
  ///
  /// The connection is initialized lazily upon the first queue operation.
  RedisTaskQueue({
    this.host = 'localhost',
    this.port = 6379,
    this.password,
    this.db,
    this.secure = false,
    this.prefix = 'bloom_jobs',
    this.defaultLeaseDuration = BloomTaskQueue.standardLeaseDuration,
  }) : super.base();

  /// Creates a [RedisTaskQueue] by parsing a Redis connection URL string.
  ///
  /// Supports `redis://` and `rediss://` URL schemes.
  /// Format: `redis[s]://[:password@]host[:port][/db]`
  factory RedisTaskQueue.fromUrl(
    String url, {
    String prefix = 'bloom_jobs',
    Duration defaultLeaseDuration = BloomTaskQueue.standardLeaseDuration,
  }) {
    final uri = Uri.parse(url);
    final isSecure = uri.scheme == 'rediss';
    final host = uri.host.isNotEmpty ? uri.host : 'localhost';
    final port = uri.hasPort ? uri.port : 6379;

    String? password;
    if (uri.userInfo.isNotEmpty) {
      if (uri.userInfo.contains(':')) {
        password = uri.userInfo.split(':')[1];
      } else {
        password = uri.userInfo;
      }
    }

    int? db;
    if (uri.pathSegments.isNotEmpty) {
      db = int.tryParse(uri.pathSegments.first);
    }

    return RedisTaskQueue(
      host: host,
      port: port,
      password: password,
      db: db,
      secure: isSecure,
      prefix: prefix,
      defaultLeaseDuration: defaultLeaseDuration,
    );
  }

  /// Creates a [RedisTaskQueue] wrapping an existing [Command] connection.
  RedisTaskQueue.fromCommand(
    Command command, {
    this.prefix = 'bloom_jobs',
    this.defaultLeaseDuration = BloomTaskQueue.standardLeaseDuration,
  })  : host = '',
        port = 0,
        password = null,
        db = null,
        secure = false,
        _command = command,
        super.base();

  String _prefixed(String key) => prefix.isEmpty ? key : '$prefix:$key';
  String _taskKey(String id) => _prefixed('task:$id');
  String get _dueTasksKey => _prefixed('due_tasks');
  String get _runningTasksKey => _prefixed('running_tasks');
  String get _allTasksKey => _prefixed('all_tasks');
  String get _idCounterKey => _prefixed('id_counter');

  Future<Command> _getCommand() async {
    if (_command != null) return _command!;

    final conn = RedisConnection();
    final cmd = secure
        ? await conn.connectSecure(host, port)
        : await conn.connect(host, port);

    if (password != null && password!.isNotEmpty) {
      await cmd.send_object(['AUTH', password!]);
    }

    if (db != null && db! > 0) {
      await cmd.send_object(['SELECT', db!]);
    }

    _connection = conn;
    _command = cmd;
    return cmd;
  }

  String _generateToken() {
    _tokenSeq++;
    return 'tok_${DateTime.now().microsecondsSinceEpoch}_$_tokenSeq';
  }

  BloomQueuedTask _taskFromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    final Map<String, dynamic> payload;
    if (rawPayload is Map) {
      payload = Map<String, dynamic>.from(rawPayload);
    } else if (rawPayload is String) {
      final decoded = jsonDecode(rawPayload);
      payload = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } else {
      payload = <String, dynamic>{};
    }

    final statusStr =
        json['status']?.toString() ?? BloomTaskStatus.pending.name;
    final status = BloomTaskStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => BloomTaskStatus.pending,
    );

    return BloomQueuedTask(
      id: json['id'].toString(),
      taskName: json['taskName'] as String,
      payload: payload,
      status: status,
      createdAt: DateTime.parse(json['createdAt'] as String),
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      maxAttempts: (json['maxAttempts'] as num?)?.toInt() ?? 3,
      token: json['token'] as String?,
      leaseExpiresAt: json['leaseExpiresAt'] != null
          ? DateTime.parse(json['leaseExpiresAt'] as String)
          : null,
      lastError: json['lastError'] as String?,
      lastStackTrace: json['lastStackTrace'] as String?,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      finishedAt: json['finishedAt'] != null
          ? DateTime.parse(json['finishedAt'] as String)
          : null,
    );
  }

  @override
  Future<BloomQueuedTask> enqueueScheduled(
    String taskName,
    Map<String, dynamic> payload,
    DateTime runAt, {
    int maxAttempts = 3,
  }) async {
    final cmd = await _getCommand();
    final rawId = await cmd.send_object(['INCR', _idCounterKey]);
    final id = rawId.toString();
    final now = DateTime.now().toUtc();
    final scheduled = runAt.toUtc();

    final task = BloomQueuedTask(
      id: id,
      taskName: taskName,
      payload: Map<String, dynamic>.from(payload),
      status: BloomTaskStatus.pending,
      createdAt: now,
      scheduledAt: scheduled,
      attempts: 0,
      maxAttempts: maxAttempts,
    );

    final rawJson = jsonEncode(task.toJson());
    await cmd.send_object(['SET', _taskKey(id), rawJson]);
    await cmd.send_object(
        ['ZADD', _dueTasksKey, scheduled.millisecondsSinceEpoch, id]);
    await cmd.send_object(['SADD', _allTasksKey, id]);

    return task;
  }

  static const String _claimLuaScript = '''
-- 1. Reclaim expired running leases before pending work
local expiredTasks = redis.call('ZRANGEBYSCORE', KEYS[2], '-inf', ARGV[1])
for i = 1, #expiredTasks do
  local expiredTaskId = expiredTasks[i]
  redis.call('ZREM', KEYS[2], expiredTaskId)
  local taskKey = ARGV[2] .. expiredTaskId
  local raw = redis.call('GET', taskKey)
  if raw then
    local task = cjson.decode(raw)
    if task['status'] == 'running' then
      local attempts = tonumber(task['attempts']) or 0
      local maxAttempts = tonumber(task['maxAttempts']) or 3
      if attempts >= maxAttempts then
        task['status'] = 'failed'
        task['finishedAt'] = ARGV[3]
        if task['lastError'] == nil or task['lastError'] == cjson.null or task['lastError'] == '' then
          task['lastError'] = 'Task lease expired'
        end
        task['token'] = nil
        task['leaseExpiresAt'] = nil
        redis.call('SET', taskKey, cjson.encode(task))
        redis.call('ZREM', KEYS[1], expiredTaskId)
      else
        task['status'] = 'pending'
        task['token'] = nil
        task['leaseExpiresAt'] = nil
        task['scheduledAt'] = ARGV[3]
        redis.call('SET', taskKey, cjson.encode(task))
        redis.call('ZADD', KEYS[1], tonumber(ARGV[1]), expiredTaskId)
      end
    end
  end
end

-- 2. Claim next pending, due task
local dueTasks = redis.call('ZRANGEBYSCORE', KEYS[1], '-inf', ARGV[1], 'LIMIT', 0, 1)
if #dueTasks == 0 then
  return nil
end

local claimTaskId = dueTasks[1]
redis.call('ZREM', KEYS[1], claimTaskId)

local taskKey = ARGV[2] .. claimTaskId
local rawClaim = redis.call('GET', taskKey)
if not rawClaim then
  return nil
end

local task = cjson.decode(rawClaim)
task['status'] = 'running'
task['attempts'] = (tonumber(task['attempts']) or 0) + 1
task['startedAt'] = ARGV[3]
task['token'] = ARGV[4]
task['leaseExpiresAt'] = ARGV[5]

local leaseExpiryMs = tonumber(ARGV[6])
redis.call('ZADD', KEYS[2], leaseExpiryMs, claimTaskId)

local updated = cjson.encode(task)
redis.call('SET', taskKey, updated)

return updated
''';

  @override
  Future<BloomQueuedTask?> claimNext(
      [DateTime? now, Duration? leaseDuration]) async {
    final cmd = await _getCommand();
    final refTime = (now ?? DateTime.now()).toUtc();
    final effectiveLease = leaseDuration ?? defaultLeaseDuration;
    final leaseExpiresAt = refTime.add(effectiveLease);
    final nowIso = refTime.toIso8601String();
    final leaseExpiresAtIso = leaseExpiresAt.toIso8601String();
    final token = _generateToken();
    final taskPrefix = _prefixed('task:');

    final result = await cmd.send_object([
      'EVAL',
      _claimLuaScript,
      2,
      _dueTasksKey,
      _runningTasksKey,
      refTime.millisecondsSinceEpoch.toString(),
      taskPrefix,
      nowIso,
      token,
      leaseExpiresAtIso,
      leaseExpiresAt.millisecondsSinceEpoch.toString(),
    ]);

    if (result == null) {
      return null;
    }

    final String rawString;
    if (result is String) {
      rawString = result;
    } else if (result is List<int>) {
      rawString = utf8.decode(result);
    } else {
      rawString = result.toString();
    }

    final map = jsonDecode(rawString) as Map<String, dynamic>;
    return _taskFromJson(map);
  }

  static const String _completeLuaScript = '''
local raw = redis.call('GET', KEYS[1])
if not raw then
  return 'ERR_NOT_FOUND'
end
local task = cjson.decode(raw)
if task['status'] ~= 'running' then
  return 'ERR_NOT_RUNNING'
end
if not ARGV[2] or ARGV[2] == '' or task['token'] ~= ARGV[2] then
  return 'ERR_TOKEN_MISMATCH'
end

task['status'] = 'succeeded'
task['lastError'] = nil
task['lastStackTrace'] = nil
task['finishedAt'] = ARGV[3]
task['token'] = nil
task['leaseExpiresAt'] = nil

redis.call('SET', KEYS[1], cjson.encode(task))
redis.call('ZREM', KEYS[2], ARGV[1])
redis.call('ZREM', KEYS[3], ARGV[1])
return 'OK'
''';

  @override
  Future<void> markCompleted(String taskId, {String? token}) async {
    if (token == null || token.isEmpty) {
      throw StateError(
        'Task with id "$taskId" cannot be marked completed: invalid or missing token.',
      );
    }

    final cmd = await _getCommand();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final result = await cmd.send_object([
      'EVAL',
      _completeLuaScript,
      3,
      _taskKey(taskId),
      _dueTasksKey,
      _runningTasksKey,
      taskId,
      token,
      nowIso,
    ]);

    final resStr = result?.toString() ?? '';
    if (resStr != 'OK') {
      throw StateError(
        'Task with id "$taskId" cannot be marked completed: not found, not running, or token mismatch.',
      );
    }
  }

  static const String _failLuaScript = '''
local raw = redis.call('GET', KEYS[1])
if not raw then
  return 'ERR_NOT_FOUND'
end
local task = cjson.decode(raw)
if task['status'] ~= 'running' then
  return 'ERR_NOT_RUNNING'
end
if not ARGV[2] or ARGV[2] == '' or task['token'] ~= ARGV[2] then
  return 'ERR_TOKEN_MISMATCH'
end

task['lastError'] = ARGV[3]
if ARGV[4] and ARGV[4] ~= '' then
  task['lastStackTrace'] = ARGV[4]
else
  task['lastStackTrace'] = nil
end
task['finishedAt'] = ARGV[5]
task['token'] = nil
task['leaseExpiresAt'] = nil

redis.call('ZREM', KEYS[3], ARGV[1])

local attempts = tonumber(task['attempts']) or 0
local maxAttempts = tonumber(task['maxAttempts']) or 3
if attempts < maxAttempts then
  task['status'] = 'pending'
  local retryAfterMs = tonumber(ARGV[6])
  task['scheduledAt'] = ARGV[7]
  redis.call('SET', KEYS[1], cjson.encode(task))
  redis.call('ZADD', KEYS[2], retryAfterMs, ARGV[1])
else
  task['status'] = 'failed'
  redis.call('SET', KEYS[1], cjson.encode(task))
  redis.call('ZREM', KEYS[2], ARGV[1])
end

return 'OK'
''';

  @override
  Future<void> markFailed(
    String taskId, {
    String? token,
    required String errorMessage,
    String? stackTrace,
    DateTime? retryAfter,
  }) async {
    if (token == null || token.isEmpty) {
      throw StateError(
        'Task with id "$taskId" cannot be marked failed: invalid or missing token.',
      );
    }

    final cmd = await _getCommand();
    final raw = await cmd.send_object(['GET', _taskKey(taskId)]);
    if (raw == null) {
      throw StateError(
        'Task with id "$taskId" cannot be marked failed: not found in queue.',
      );
    }

    final rawString = raw is String
        ? raw
        : (raw is List<int> ? utf8.decode(raw) : raw.toString());
    final map = jsonDecode(rawString) as Map<String, dynamic>;
    final task = _taskFromJson(map);

    if (task.status != BloomTaskStatus.running || task.token != token) {
      throw StateError(
        'Task with id "$taskId" cannot be marked failed: not running or token mismatch.',
      );
    }

    final now = DateTime.now().toUtc();
    final effectiveRetryAfter = retryAfter?.toUtc() ??
        now.add(Duration(seconds: (1 << task.attempts).clamp(1, 60)));

    final result = await cmd.send_object([
      'EVAL',
      _failLuaScript,
      3,
      _taskKey(taskId),
      _dueTasksKey,
      _runningTasksKey,
      taskId,
      token,
      errorMessage,
      stackTrace ?? '',
      now.toIso8601String(),
      effectiveRetryAfter.millisecondsSinceEpoch.toString(),
      effectiveRetryAfter.toIso8601String(),
    ]);

    final resStr = result?.toString() ?? '';
    if (resStr != 'OK') {
      throw StateError(
        'Task with id "$taskId" cannot be marked failed: not found, not running, or token mismatch.',
      );
    }
  }

  @override
  Future<List<BloomQueuedTask>> allTasks() async {
    final cmd = await _getCommand();
    final members = await cmd.send_object(['SMEMBERS', _allTasksKey]);
    if (members is! List || members.isEmpty) {
      return List<BloomQueuedTask>.unmodifiable([]);
    }

    final tasks = <BloomQueuedTask>[];
    for (final member in members) {
      final taskId = member.toString();
      final raw = await cmd.send_object(['GET', _taskKey(taskId)]);
      if (raw != null) {
        final rawString = raw is String
            ? raw
            : (raw is List<int> ? utf8.decode(raw) : raw.toString());
        final map = jsonDecode(rawString) as Map<String, dynamic>;
        tasks.add(_taskFromJson(map));
      }
    }

    tasks.sort((a, b) {
      final cmp = a.scheduledAt.compareTo(b.scheduledAt);
      if (cmp != 0) return cmp;
      final aNum = int.tryParse(a.id);
      final bNum = int.tryParse(b.id);
      if (aNum != null && bNum != null) {
        return aNum.compareTo(bNum);
      }
      return a.id.compareTo(b.id);
    });

    return List<BloomQueuedTask>.unmodifiable(tasks);
  }

  @override
  Future<BloomQueuedTask?> getTask(String id) async {
    final cmd = await _getCommand();
    final raw = await cmd.send_object(['GET', _taskKey(id)]);
    if (raw == null) return null;

    final rawString = raw is String
        ? raw
        : (raw is List<int> ? utf8.decode(raw) : raw.toString());
    final map = jsonDecode(rawString) as Map<String, dynamic>;
    return _taskFromJson(map);
  }

  @override
  Future<void> clear() async {
    final cmd = await _getCommand();
    if (prefix.isEmpty) {
      await cmd.send_object(['FLUSHDB']);
      return;
    }

    final keysResult = await cmd.send_object(['KEYS', '$prefix:*']);
    if (keysResult is List && keysResult.isNotEmpty) {
      final keys = keysResult.map((k) => k.toString()).toList();
      await cmd.send_object(['DEL', ...keys]);
    }
  }

  /// Closes the underlying Redis connection if opened by this instance.
  Future<void> close() async {
    if (_connection != null) {
      await _connection!.close();
      _connection = null;
      _command = null;
    }
  }
}
