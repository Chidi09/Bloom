// lib/src/redis_cache.dart
import 'dart:convert';
import 'package:redis/redis.dart';
import 'cache.dart';

/// A distributed [BloomCache] implementation backed by Redis via the official
/// `package:redis` client.
///
/// Features:
/// - Native Redis key expiration with millisecond precision (`PX` flag).
/// - Automatic JSON serialization and deserialization for stored values.
/// - Optional key prefix namespacing to isolate cache spaces within a single Redis instance.
/// - Lazy connection initialization and lifecycle management.
class RedisCache extends BloomCache {
  /// The Redis server hostname.
  final String host;

  /// The Redis server port.
  final int port;

  /// Optional password used to authenticate against Redis.
  final String? password;

  /// Optional database index to select after connecting.
  final int? db;

  /// Whether to connect using TLS/SSL (`rediss://`).
  final bool secure;

  /// Optional key prefix prepended to all cache keys.
  final String prefix;

  RedisConnection? _connection;
  Command? _command;

  /// Creates a [RedisCache] by configuring connection parameters.
  ///
  /// The connection to Redis will be established lazily upon the first cache operation.
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
  /// Example: `redis://:secret@localhost:6379/0` or `rediss://...` (TLS).
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

  @override
  Future<void> invalidateTag(String tag) => invalidateTags([tag]);

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
  Future<void> close() async {
    if (_connection != null) {
      await _connection!.close();
      _connection = null;
      _command = null;
    }
  }
}
