// lib/src/redis_cache.dart
import 'dart:convert';
import 'package:redis/redis.dart';
import 'cache.dart';

/// A distributed [BloomCache] implementation backed by Redis via the official
/// `package:redis` client.
///
/// ### Key Features
/// - **Atomic Lua Scripts**: Atomic operations for set/tag replacement, deletion, tag invalidation,
///   and scan-based clearing.
/// - **Scalable Key-to-Tag Indexing**: Uses tracked key-to-tag indexes (`__key_tags:<key>`)
///   and tag sets (`__tags:<tag>`) to maintain tag associations in O(T) without `KEYS` scans.
/// - **Native TTL**: High-precision key expiration using Redis `PX` (millisecond) flags.
/// - **JSON Serialization**: Automatic encoding/decoding for primitives, maps, and lists.
/// - **Prefix Namespacing & Safe Clear**: Prepends [prefix] to all keys and tag indexes.
///   [clear] safely scans and deletes only prefixed keys; clearing an unprefixed cache
///   requires explicit opt-in ([allowEmptyPrefixClear]) and never executes `FLUSHDB`.
/// - **Lazy Connection**: Automatically initializes the Redis connection upon first command execution.
///
/// Example:
/// ```dart
/// // Connect via URL
/// final cache = RedisCache.fromUrl('redis://:secret@127.0.0.1:6379/0', prefix: 'myapp');
///
/// // Store with 1-hour TTL and tags
/// await cache.set(
///   'product:99',
///   {'name': 'Mechanical Keyboard', 'price': 149.99},
///   ttl: const Duration(hours: 1),
///   tags: ['products', 'hardware'],
/// );
///
/// final product = await cache.get<Map<String, dynamic>>('product:99');
/// print(product?['name']); // "Mechanical Keyboard"
///
/// // Invalidate all products
/// await cache.invalidateTag('products');
///
/// // Cleanup connection on shutdown
/// await cache.close();
/// ```
class RedisCache extends BloomCache {
  /// The Redis server hostname.
  final String host;

  /// The Redis server port.
  final int port;

  /// Optional password used to authenticate against Redis (`AUTH`).
  final String? password;

  /// Optional database index to select (`SELECT`) after connecting.
  final int? db;

  /// Whether to connect using TLS/SSL (`rediss://`).
  final bool secure;

  /// Optional key prefix prepended to all cache keys and tag sets.
  final String prefix;

  /// Whether to permit [clear] when [prefix] is empty. Defaults to `false` for safety.
  final bool allowEmptyPrefixClear;

  RedisConnection? _connection;
  Command? _command;

  /// Creates a [RedisCache] by configuring connection parameters.
  ///
  /// The connection to Redis will be established lazily upon the first cache operation.
  ///
  /// Parameters:
  /// - [host]: Redis server hostname. Defaults to `'localhost'`.
  /// - [port]: Redis server port. Defaults to `6379`.
  /// - [password]: Optional authentication password.
  /// - [db]: Optional database numerical index (0-15).
  /// - [secure]: If `true`, initiates a TLS/SSL connection. Defaults to `false`.
  /// - [prefix]: Optional prefix prepended to all keys. Defaults to `''`.
  /// - [allowEmptyPrefixClear]: If `true`, permits calling [clear] when [prefix] is empty.
  ///   Defaults to `false` to prevent accidental database-wide clearing.
  ///
  /// Example:
  /// ```dart
  /// final cache = RedisCache(host: 'redis.internal', port: 6379, prefix: 'bloom');
  /// ```
  RedisCache({
    this.host = 'localhost',
    this.port = 6379,
    this.password,
    this.db,
    this.secure = false,
    this.prefix = '',
    this.allowEmptyPrefixClear = false,
  });

  /// Creates a [RedisCache] by parsing a standard Redis connection URL string.
  ///
  /// Supports both plaintext (`redis://`) and TLS (`rediss://`) URI schemes.
  /// URI format: `redis[s]://[:password@]host[:port][/db]`
  ///
  /// Parameters:
  /// - [url]: The full Redis connection URL.
  /// - [prefix]: Optional key prefix prepended to all cache keys. Defaults to `''`.
  /// - [allowEmptyPrefixClear]: Whether to allow clearing when prefix is empty. Defaults to `false`.
  ///
  /// Example:
  /// ```dart
  /// final cache = RedisCache.fromUrl(
  ///   'redis://:mypassword@cache.example.com:6380/1',
  ///   prefix: 'v1',
  /// );
  /// ```
  factory RedisCache.fromUrl(
    String url, {
    String prefix = '',
    bool allowEmptyPrefixClear = false,
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

    return RedisCache(
      host: host,
      port: port,
      password: password,
      db: db,
      secure: isSecure,
      prefix: prefix,
      allowEmptyPrefixClear: allowEmptyPrefixClear,
    );
  }

  /// Creates a [RedisCache] wrapping an already established `package:redis` [Command] interface.
  ///
  /// Useful when sharing a pre-existing connection or mock instance across components.
  ///
  /// Parameters:
  /// - [command]: The initialized [Command] instance.
  /// - [prefix]: Optional key prefix prepended to all cache keys. Defaults to `''`.
  /// - [allowEmptyPrefixClear]: Whether to allow clearing when prefix is empty. Defaults to `false`.
  RedisCache.fromCommand(
    Command command, {
    this.prefix = '',
    this.allowEmptyPrefixClear = false,
  })  : host = '',
        port = 0,
        password = null,
        db = null,
        secure = false,
        _command = command;

  String _prefixed(String key) => prefix.isEmpty ? key : '$prefix:$key';
  String _keyTagsKey(String key) =>
      prefix.isEmpty ? '__key_tags:$key' : '$prefix:__key_tags:$key';
  String _tagPrefix() => prefix.isEmpty ? '__tags:' : '$prefix:__tags:';
  String _keyTagsPrefix() =>
      prefix.isEmpty ? '__key_tags:' : '$prefix:__key_tags:';
  String _cacheKeyPrefix() => prefix.isEmpty ? '' : '$prefix:';

  static const String _setLuaScript = '''
local cacheKey = KEYS[1]
local keyTagsKey = KEYS[2]
local val = ARGV[1]
local ttlMs = tonumber(ARGV[2])
local tagPrefix = ARGV[3]
local memberKey = ARGV[4]

local oldTags = redis.call('SMEMBERS', keyTagsKey)
local newTags = {}
for i = 5, #ARGV do
  newTags[ARGV[i]] = true
end

for _, oldTag in ipairs(oldTags) do
  if not newTags[oldTag] then
    redis.call('SREM', tagPrefix .. oldTag, memberKey)
  end
end

redis.call('DEL', keyTagsKey)
for i = 5, #ARGV do
  local tag = ARGV[i]
  redis.call('SADD', tagPrefix .. tag, memberKey)
  redis.call('SADD', keyTagsKey, tag)
end

if ttlMs and ttlMs > 0 then
  redis.call('SET', cacheKey, val, 'PX', ttlMs)
  if #ARGV >= 5 then
    redis.call('PEXPIRE', keyTagsKey, ttlMs)
  end
else
  redis.call('SET', cacheKey, val)
end

return 1
''';

  static const String _deleteLuaScript = '''
local cacheKey = KEYS[1]
local keyTagsKey = KEYS[2]
local tagPrefix = ARGV[1]
local memberKey = ARGV[2]

local oldTags = redis.call('SMEMBERS', keyTagsKey)
for _, tag in ipairs(oldTags) do
  redis.call('SREM', tagPrefix .. tag, memberKey)
end

redis.call('DEL', keyTagsKey)
redis.call('DEL', cacheKey)
return 1
''';

  static const String _invalidateTagsLuaScript = '''
local tagPrefix = ARGV[1]
local keyTagsPrefix = ARGV[2]
local cacheKeyPrefix = ARGV[3]

local uniqueKeys = {}
local tagSetKeys = {}

for i = 4, #ARGV do
  local tag = ARGV[i]
  local tagSetKey = tagPrefix .. tag
  table.insert(tagSetKeys, tagSetKey)
  local members = redis.call('SMEMBERS', tagSetKey)
  for _, memberKey in ipairs(members) do
    uniqueKeys[memberKey] = true
  end
end

for memberKey, _ in pairs(uniqueKeys) do
  local keyTagsKey = keyTagsPrefix .. memberKey
  local cacheKey = cacheKeyPrefix == '' and memberKey or (cacheKeyPrefix .. memberKey)

  local tags = redis.call('SMEMBERS', keyTagsKey)
  for _, tag in ipairs(tags) do
    redis.call('SREM', tagPrefix .. tag, memberKey)
  end

  redis.call('DEL', keyTagsKey)
  redis.call('DEL', cacheKey)
end

for _, tagSetKey in ipairs(tagSetKeys) do
  redis.call('DEL', tagSetKey)
end

return 1
''';

  static const String _clearScanLuaScript = '''
local matchPattern = ARGV[1]
local cursor = "0"
repeat
  local scanResult = redis.call("SCAN", cursor, "MATCH", matchPattern, "COUNT", 500)
  cursor = scanResult[1]
  local keys = scanResult[2]
  if #keys > 0 then
    redis.call("DEL", unpack(keys))
  end
until cursor == "0"
return 1
''';

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

  /// Retrieves the value associated with [key] from Redis.
  ///
  /// Sends a `GET` command to Redis. If the key exists and has not expired,
  /// deserializes and casts the stored JSON string to [T].
  /// Returns `null` if the key does not exist or has expired.
  @override
  Future<T?> get<T>(String key) async {
    final cmd = await _getCommand();
    final result = await cmd.send_object(['GET', _prefixed(key)]);

    if (result == null) {
      return null;
    }

    final rawString = result is String ? result : result.toString();
    return decodeCacheValue<T>(rawString);
  }

  /// Stores [value] under [key] in Redis with optional [ttl] and [tags].
  ///
  /// Atomically executes an atomic Lua script that:
  /// 1. Removes this key from old tag sets that are no longer associated.
  /// 2. Sets new tag associations in both tag sets and the tracked key-to-tag index.
  /// 3. Sets the key with optional millisecond TTL (`PX`).
  @override
  Future<void> set<T>(String key, T value,
      {Duration? ttl, List<String>? tags}) async {
    final cmd = await _getCommand();
    final raw = jsonEncode(value);
    final cacheKey = _prefixed(key);
    final keyTagsKey = _keyTagsKey(key);
    final ttlMsStr = ttl != null ? ttl.inMilliseconds.toString() : '';
    final uniqueTags = tags != null ? tags.toSet().toList() : <String>[];

    final args = <dynamic>[
      'EVAL',
      _setLuaScript,
      2, // numKeys
      cacheKey,
      keyTagsKey,
      raw,
      ttlMsStr,
      _tagPrefix(),
      key,
      ...uniqueTags,
    ];

    await cmd.send_object(args);
  }

  /// Deletes the cache entry associated with [key] and removes all its tag associations.
  ///
  /// Executes an atomic Lua script that cleans up tag sets and deletes the key.
  @override
  Future<void> delete(String key) async {
    final cmd = await _getCommand();
    final cacheKey = _prefixed(key);
    final keyTagsKey = _keyTagsKey(key);

    await cmd.send_object([
      'EVAL',
      _deleteLuaScript,
      2, // numKeys
      cacheKey,
      keyTagsKey,
      _tagPrefix(),
      key,
    ]);
  }

  /// Removes every entry labelled with [tag].
  ///
  /// Delegates to [invalidateTags] with a single-element list.
  @override
  Future<void> invalidateTag(String tag) => invalidateTags([tag]);

  /// Removes every entry labelled with ANY of the given [tags] atomically.
  ///
  /// Executes an atomic Lua script that resolves all keys for the specified tags,
  /// cleans up their key-to-tag indexes and all other tag set memberships, and deletes the keys.
  @override
  Future<void> invalidateTags(List<String> tags) async {
    if (tags.isEmpty) return;
    final cmd = await _getCommand();
    final uniqueTags = tags.toSet().toList();

    await cmd.send_object([
      'EVAL',
      _invalidateTagsLuaScript,
      0, // numKeys
      _tagPrefix(),
      _keyTagsPrefix(),
      _cacheKeyPrefix(),
      ...uniqueTags,
    ]);
  }

  /// Clears entries from Redis.
  ///
  /// Uses an atomic Lua script with a cursor-based `SCAN` loop matching the configured [prefix].
  /// Never executes `FLUSHDB`.
  /// If [prefix] is empty, [allowEmptyPrefixClear] must be explicitly set to `true`,
  /// otherwise throws a [StateError] to prevent accidental database wiping.
  @override
  Future<void> clear() async {
    if (prefix.isEmpty && !allowEmptyPrefixClear) {
      throw StateError(
        'Clearing an unprefixed RedisCache is unsafe and disabled by default. '
        'Provide a non-empty prefix or instantiate RedisCache with allowEmptyPrefixClear: true.',
      );
    }

    final cmd = await _getCommand();
    final matchPattern = prefix.isEmpty ? '*' : '$prefix:*';

    await cmd.send_object([
      'EVAL',
      _clearScanLuaScript,
      0, // numKeys
      matchPattern,
    ]);
  }

  /// Closes the underlying Redis connection if it was initialized by this cache.
  ///
  /// Subsequent calls after closing will automatically re-open a new connection
  /// on the next command execution.
  ///
  /// Example:
  /// ```dart
  /// await cache.close();
  /// ```
  Future<void> close() async {
    if (_connection != null) {
      await _connection!.close();
      _connection = null;
      _command = null;
    }
  }
}
