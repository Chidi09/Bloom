// lib/src/adapters/supabase_adapter.dart
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../core/logger.dart';
import '../data/auth.dart';
import '../data/http_client.dart';
import '../data/repository.dart';

/// Represents an authenticated Supabase user profile.
class BloomSupabaseUser {
  final String id;
  final String email;
  final String? accessToken;
  final String? refreshToken;
  final Map<String, dynamic> userMetadata;

  const BloomSupabaseUser({
    required this.id,
    required this.email,
    this.accessToken,
    this.refreshToken,
    this.userMetadata = const {},
  });

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

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'user_metadata': userMetadata,
  };
}

/// Official Bloom authentication adapter for Supabase with real token refresh support.
class BloomSupabaseAuthAdapter extends BloomAuth<BloomSupabaseUser> {
  final String supabaseUrl;
  final String supabaseAnonKey;
  final BloomHttpClient _http;
  final sb.SupabaseClient? supabaseClient;

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
    supabaseClient?.auth.onAuthStateChange.listen((data) {
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

      final token = data['access_token']?.toString() ?? '';
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
class BloomSupabaseTableRepository<T> implements BloomCrudRepository<T, String> {
  final String tableName;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final T Function(Map<String, dynamic> json) fromJson;
  final Map<String, dynamic> Function(T item) toJson;
  final BloomHttpClient _http;

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
