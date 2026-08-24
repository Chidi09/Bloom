/// Supabase authentication and CRUD repository adapters for Bloom.
library;

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../core/logger.dart';
import '../data/auth.dart';
import '../data/http_client.dart';
import '../data/repository.dart';

/// Represents an authenticated Supabase user profile.
///
/// Contains user UUID, email address, JWT access token, refresh token, and user metadata.
///
/// Example:
/// ```dart
/// final user = BloomSupabaseUser(
///   id: 'usr_123',
///   email: 'user@example.com',
///   accessToken: 'jwt.token.here',
/// );
/// ```
class BloomSupabaseUser {
  /// Unique user UUID string.
  final String id;

  /// User email address.
  final String email;

  /// JWT access token.
  final String? accessToken;

  /// Supabase refresh token.
  final String? refreshToken;

  /// Custom user metadata key-value map.
  final Map<String, dynamic> userMetadata;

  /// Creates a [BloomSupabaseUser].
  const BloomSupabaseUser({
    required this.id,
    required this.email,
    this.accessToken,
    this.refreshToken,
    this.userMetadata = const {},
  });

  /// Constructs a [BloomSupabaseUser] from a JSON [json] map.
  factory BloomSupabaseUser.fromJson(Map<String, dynamic> json) {
    return BloomSupabaseUser(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      accessToken: json['access_token']?.toString(),
      refreshToken: json['refresh_token']?.toString(),
      userMetadata: json['user_metadata'] is Map
          ? Map<String, dynamic>.from(json['user_metadata'] as Map)
          : const {},
    );
  }

  /// Serializes user profile to a JSON map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'user_metadata': userMetadata,
  };
}

/// Official Bloom authentication adapter for Supabase with real token refresh support.
///
/// Integrates with [BloomAuth] to provide reactive authentication state signals (`currentUser`, `isAuthenticated`).
///
/// Example:
/// ```dart
/// final auth = BloomSupabaseAuthAdapter(
///   supabaseUrl: 'https://xyz.supabase.co',
///   supabaseAnonKey: 'anon-key-here',
/// );
/// await auth.signInWithPassword(email: 'user@example.com', password: 'secret');
/// ```
class BloomSupabaseAuthAdapter extends BloomAuth<BloomSupabaseUser> {

  /// Base Supabase backend URL.
  final String supabaseUrl;

  /// Supabase anonymous API key.
  final String supabaseAnonKey;
  final BloomHttpClient _http;

  /// Optional live [sb.SupabaseClient] instance to observe real-time auth changes.
  final sb.SupabaseClient? supabaseClient;
  StreamSubscription<sb.AuthState>? _authStateSubscription;

  /// Creates a [BloomSupabaseAuthAdapter].
  BloomSupabaseAuthAdapter({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.supabaseClient,
    super.storage,
    String sessionKey = 'bloom_supabase_session',
  })  : _http = BloomHttpClient(baseUrl: '$supabaseUrl/auth/v1'),
        super(
          sessionKey: sessionKey,
          fromJson: (json) => BloomSupabaseUser.fromJson(json),
          toJson: (user) => user.toJson(),
        ) {
    _http.requestInterceptors.add((req) {
      req.headers['apikey'] = supabaseAnonKey;
      return req;
    });

    // If a live SupabaseClient is provided, listen to auth state changes
    if (supabaseClient != null) {
      _authStateSubscription = supabaseClient!.auth.onAuthStateChange.listen((data) {
        final session = data.session;
        if (session != null) {
          final user = BloomSupabaseUser(
            id: session.user.id,
            email: session.user.email ?? '',
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            userMetadata: session.user.userMetadata ?? const {},
          );
          setSession(user: user, token: session.accessToken);
        }
      });
    }
  }

  /// Cancel auth state listeners and release resources.
  Future<void> dispose() async {
    await _authStateSubscription?.cancel();
    _authStateSubscription = null;
  }

  /// Sign in with email and password via Supabase Auth API.
  Future<BloomSupabaseUser> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      if (supabaseClient != null) {
        final res = await supabaseClient!.auth.signInWithPassword(
          email: email,
          password: password,
        );
        final session = res.session;
        final user = BloomSupabaseUser(
          id: res.user?.id ?? '',
          email: res.user?.email ?? email,
          accessToken: session?.accessToken,
          refreshToken: session?.refreshToken,
          userMetadata: res.user?.userMetadata ?? const {},
        );
        if (session != null) {
          await setSession(user: user, token: session.accessToken);
        }
        return user;
      }

      final data = await _http.post<Map<String, dynamic>>(
        '/token?grant_type=password',
        body: {'email': email, 'password': password},
      );

      final userMap = data['user'] as Map<String, dynamic>? ?? {};
      final token = data['access_token']?.toString() ?? '';
      final user = BloomSupabaseUser(
        id: userMap['id']?.toString() ?? '',
        email: userMap['email']?.toString() ?? email,
        accessToken: token,
        refreshToken: data['refresh_token']?.toString(),
        userMetadata: userMap['user_metadata'] is Map
            ? Map<String, dynamic>.from(userMap['user_metadata'] as Map)
            : const {},
      );

      await setSession(user: user, token: token);
      return user;
    } catch (e) {
      logger.error('BloomSupabaseAuth: signIn error: $e');
      rethrow;
    }
  }

  /// Sign up a new user via Supabase Auth API.
  Future<BloomSupabaseUser> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    try {
      if (supabaseClient != null) {
        final res = await supabaseClient!.auth.signUp(
          email: email,
          password: password,
          data: data,
        );
        final session = res.session;
        final user = BloomSupabaseUser(
          id: res.user?.id ?? '',
          email: res.user?.email ?? email,
          accessToken: session?.accessToken,
          refreshToken: session?.refreshToken,
          userMetadata: res.user?.userMetadata ?? (data ?? const {}),
        );
        if (session != null) {
          await setSession(user: user, token: session.accessToken);
        }
        return user;
      }

      final json = await _http.post<Map<String, dynamic>>(
        '/signup',
        body: {
          'email': email,
          'password': password,
          if (data != null) 'data': data,
        },
      );

      final token = json['access_token']?.toString() ?? '';
      final user = BloomSupabaseUser(
        id: json['id']?.toString() ?? '',
        email: json['email']?.toString() ?? email,
        accessToken: token,
        refreshToken: json['refresh_token']?.toString(),
        userMetadata: json['user_metadata'] is Map
            ? Map<String, dynamic>.from(json['user_metadata'] as Map)
            : (data ?? const {}),
      );

      if (token.isNotEmpty) {
        await setSession(user: user, token: token);
      }
      return user;
    } catch (e) {
      logger.error('BloomSupabaseAuth: signUp error: $e');
      rethrow;
    }
  }

  /// Refresh the active Supabase session using the stored refresh token.
  Future<BloomSupabaseUser?> refreshSession() async {
    final current = currentUser.value;
    if (current?.refreshToken == null) {
      logger.debug('BloomSupabaseAuth: No refresh token available.');
      return null;
    }

    try {
      if (supabaseClient != null) {
        final res = await supabaseClient!.auth.refreshSession();
        final session = res.session;
        if (session != null) {
          final user = BloomSupabaseUser(
            id: session.user.id,
            email: session.user.email ?? current!.email,
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            userMetadata: session.user.userMetadata ?? current!.userMetadata,
          );
          await setSession(user: user, token: session.accessToken);
          return user;
        }
      }

      final data = await _http.post<Map<String, dynamic>>(
        '/token?grant_type=refresh_token',
        body: {'refresh_token': current!.refreshToken},
      );

      final token = data['access_token']?.toString();
      if (token == null || token.isEmpty) {
        logger.error('BloomSupabaseAuth: Refresh response did not return an access token.');
        return null;
      }

      final userMap = data['user'] as Map<String, dynamic>? ?? {};
      final user = BloomSupabaseUser(
        id: userMap['id']?.toString() ?? current.id,
        email: userMap['email']?.toString() ?? current.email,
        accessToken: token,
        refreshToken: data['refresh_token']?.toString() ?? current.refreshToken,
        userMetadata: userMap['user_metadata'] is Map
            ? Map<String, dynamic>.from(userMap['user_metadata'] as Map)
            : current.userMetadata,
      );

      await setSession(user: user, token: token);
      return user;
    } catch (e) {
      logger.error('BloomSupabaseAuth: refreshSession error: $e');
      return null;
    }
  }
}

/// Strongly-typed CRUD repository adapter for Supabase REST tables.
///
/// Implements [BloomCrudRepository] to perform queries, inserts, updates, and deletes against Supabase PostgREST tables.
///
/// Example:
/// ```dart
/// final todoRepo = BloomSupabaseTableRepository<Todo>(
///   tableName: 'todos',
///   supabaseUrl: 'https://xyz.supabase.co',
///   supabaseAnonKey: 'anon-key',
///   fromJson: Todo.fromJson,
///   toJson: (t) => t.toJson(),
/// );
/// final todos = await todoRepo.findAll();
/// ```
class BloomSupabaseTableRepository<T> implements BloomCrudRepository<T, String> {
  /// Target Supabase table name.
  final String tableName;

  /// Supabase project URL.
  final String supabaseUrl;

  /// Supabase anonymous API key.
  final String supabaseAnonKey;

  /// Deserializer function converting Supabase row JSON maps to [T].
  final T Function(Map<String, dynamic> json) fromJson;

  /// Serializer function converting [T] entity instances to JSON maps.
  final Map<String, dynamic> Function(T item) toJson;
  final BloomHttpClient _http;

  /// Creates a [BloomSupabaseTableRepository] targeting [tableName].
  BloomSupabaseTableRepository({

    required this.tableName,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.fromJson,
    required this.toJson,
    String? Function()? authTokenProvider,
    String? bearerToken,
  }) : _http = BloomHttpClient(
          baseUrl: '$supabaseUrl/rest/v1/$tableName',
          authTokenProvider: authTokenProvider,
          authToken: bearerToken,
        ) {
    _http.requestInterceptors.add((req) {
      req.headers['apikey'] = supabaseAnonKey;
      req.headers['Prefer'] = 'return=representation';
      return req;
    });
  }

  @override
  Future<List<T>> findAll() async {
    final list = await _http.get<List<dynamic>>('?select=*');
    return list.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<T?> findById(String id) async {
    final list = await _http.get<List<dynamic>>('?id=eq.$id&select=*');
    if (list.isEmpty) return null;
    return fromJson(list.first as Map<String, dynamic>);
  }

  @override
  Future<T> create(T item) async {
    final list = await _http.post<List<dynamic>>('', body: toJson(item));
    return fromJson(list.first as Map<String, dynamic>);
  }

  @override
  Future<T> update(String id, T item) async {
    final list = await _http.patch<List<dynamic>>('?id=eq.$id', body: toJson(item));
    return fromJson(list.first as Map<String, dynamic>);
  }

  @override
  Future<bool> delete(String id) async {
    await _http.delete('?id=eq.$id');
    return true;
  }
}
