// lib/src/redis_cache.dart
import 'dart:convert';
import 'package:redis/redis.dart';
import 'cache.dart';

/// A distributed [BloomCache] implementation backed by Redis via the official
/// `package:redis` client.
///
/// ### Key Features
/// - **Native TTL**: High-precision key expiration using Redis `PX` (millisecond) flags.
/// - **JSON Serialization**: Automatic encoding/decoding for primitives, maps, and lists.
/// - **Prefix Namespacing**: Optional [prefix] prepended to all keys (e.g. `'staging:cache'`),
///   preventing collisions in shared Redis environments.
/// - **Tag-Based Invalidation**: Uses dedicated Redis SETs (`__tags:<tag>`) to track and
///   invalidate all keys associated with specific tags in O(N) where N is the number of keys.
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
  });

  /// Creates a [RedisCache] by parsing a standard Redis connection URL string.
  ///
  /// Supports both plaintext (`redis://`) and TLS (`rediss://`) URI schemes.
  /// URI format: `redis[s]://[:password@]host[:port][/db]`
  ///
  /// Parameters:
  /// - [url]: The full Redis connection URL.
  /// - [prefix]: Optional key prefix prepended to all cache keys. Defaults to `''`.
  ///
  /// Example:
  /// ```dart
  /// final cache = RedisCache.fromUrl(
  ///   'redis://:mypassword@cache.example.com:6380/1',
  ///   prefix: 'v1',
  /// );
  /// ```
  factory RedisCache.fromUrl(String url, {String prefix = ''}) {
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
    );
  }

  /// Creates a [RedisCache] wrapping an already established `package:redis` [Command] interface.
  ///
  /// Useful when sharing a pre-existing connection or mock instance across components.
  ///
  /// Parameters:
  /// - [command]: The initialized [Command] instance.
  /// - [prefix]: Optional key prefix prepended to all cache keys. Defaults to `''`.
  RedisCache.fromCommand(Command command, {this.prefix = ''})
      : host = '',
        port = 0,
        password = null,
        db = null,
        secure = false,
        _command = command;

  String _prefixed(String key) => prefix.isEmpty ? key : '$prefix:$key';

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
  /// Executes a `SET` command with optional `PX` (millisecond) expiration flag.
  /// Cleans up any prior tag associations for this key and adds the key to the
  /// corresponding Redis tag sets (`SADD`).
  @override
  Future<void> set<T>(String key, T value, {Duration? ttl, List<String>? tags}) async {
    final cmd = await _getCommand();
    final raw = jsonEncode(value);
    final k = _prefixed(key);

    if (ttl != null) {
      await cmd.send_object(['SET', k, raw, 'PX', ttl.inMilliseconds]);
    } else {
      await cmd.send_object(['SET', k, raw]);
    }

    // Drop the key from any tag set it previously belonged to before adding
    // the new ones, so narrowing a key's tags on overwrite cannot leave it
    // reachable from a tag it no longer carries.
    await _removeKeyFromAllTagSets(cmd, k);

    if (tags != null && tags.isNotEmpty) {
      for (final tag in tags.toSet()) {
        await cmd.send_object(['SADD', _tagSetKey(tag), k]);
      }
    }
  }

  /// Deletes the cache entry associated with [key] from Redis.
  ///
  /// Sends a `DEL` command and removes [key] from any tag sets it belonged to.
  @override
  Future<void> delete(String key) async {
    final cmd = await _getCommand();
    final k = _prefixed(key);
    await cmd.send_object(['DEL', k]);
    await _removeKeyFromAllTagSets(cmd, k);
  }

  /// Namespaced key of the Redis SET holding every cache key carrying [tag].
  ///
  /// The `__tags` segment keeps tag sets in a namespace of their own so a tag
  /// can never collide with a cache key of the same name.
  String _tagSetKey(String tag) =>
      prefix.isEmpty ? '__tags:$tag' : '$prefix:__tags:$tag';

  /// Pattern matching every tag set in this cache's namespace.
  String get _tagSetPattern => prefix.isEmpty ? '__tags:*' : '$prefix:__tags:*';

  /// Removes an already-prefixed [prefixedKey] from every tag set it appears in.
  Future<void> _removeKeyFromAllTagSets(Command cmd, String prefixedKey) async {
    final sets = await cmd.send_object(['KEYS', _tagSetPattern]);
    if (sets is List) {
      for (final setKey in sets) {
        await cmd.send_object(['SREM', setKey.toString(), prefixedKey]);
      }
    }
  }

  /// Removes every entry labelled with [tag].
  ///
  /// Delegates to [invalidateTags] with a single-element list.
  @override
  Future<void> invalidateTag(String tag) => invalidateTags([tag]);

  /// Removes every entry labelled with ANY of the given [tags].
  ///
  /// Queries each tag's Redis SET (`SMEMBERS`) to resolve all associated keys,
  /// deletes those keys via a single batch `DEL`, and removes the tag sets themselves.
  @override
  Future<void> invalidateTags(List<String> tags) async {
    if (tags.isEmpty) return;
    final cmd = await _getCommand();

    final keys = <String>{};
    final tagSetKeys = <String>[];
    for (final tag in tags.toSet()) {
      final setKey = _tagSetKey(tag);
      tagSetKeys.add(setKey);
      final members = await cmd.send_object(['SMEMBERS', setKey]);
      if (members is List) {
        for (final m in members) {
          keys.add(m.toString());
        }
      }
    }

    // A key that expired via its Redis TTL leaves a dangling member behind in
    // its tag set, because Redis expiry does not notify the set. That is
    // harmless rather than a bug: DEL on an already-absent key is a no-op, so
    // invalidation simply deletes some keys that were already gone. The
    // dangling member itself disappears when the tag set is deleted below.
    if (keys.isNotEmpty) {
      await cmd.send_object(['DEL', ...keys]);
    }
    await cmd.send_object(['DEL', ...tagSetKeys]);
  }

  /// Clears entries from Redis.
  ///
  /// If [prefix] is empty, executes `FLUSHDB` to flush the active Redis database.
  /// If [prefix] is set, finds and deletes all keys matching `$prefix:*` while leaving
  /// unrelated keys untouched.
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

