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
  final String host;
  final int port;
  final String? password;
  final int? db;
  final bool secure;
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
  Future<void> set<T>(String key, T value, {Duration? ttl}) async {
    final cmd = await _getCommand();
    final raw = jsonEncode(value);
    final k = _prefixed(key);

    if (ttl != null) {
      await cmd.send_object(['SET', k, raw, 'PX', ttl.inMilliseconds]);
    } else {
      await cmd.send_object(['SET', k, raw]);
    }
  }

  @override
  Future<void> delete(String key) async {
    final cmd = await _getCommand();
    await cmd.send_object(['DEL', _prefixed(key)]);
  }

  @override
  Future<void> clear() async {
    final cmd = await _getCommand();
    if (prefix.isEmpty) {
      await cmd.send_object(['FLUSHDB']);
    } else {
      final keysResult = await cmd.send_object(['KEYS', '$prefix:*']);
      if (keysResult is List && keysResult.isNotEmpty) {
        final keys = keysResult.map((k) => k.toString()).toList();
        await cmd.send_object(['DEL', ...keys]);
      }
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
