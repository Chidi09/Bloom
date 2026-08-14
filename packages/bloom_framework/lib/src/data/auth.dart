// lib/src/data/auth.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import '../core/logger.dart';
import '../di/container.dart';
import '../router/route.dart';
import '../state/signals.dart';
import 'storage.dart';

/// Base non-generic interface for Bloom authentication session management.
abstract class BloomAuthBase {
  ReadonlySignal<bool> get isAuthenticated;
  ReadonlySignal<String?> get token;
  Future<void> logout();
}

/// Reactive user session manager and persistence layer.
class BloomAuth<U> implements BloomAuthBase {
  final BloomStorageAdapter? storage;
  final U Function(Map<String, dynamic> json)? fromJson;
  final Map<String, dynamic> Function(U user)? toJson;
  final String sessionKey;

  late final Signal<U?> _currentUser;
  late final Signal<String?> _token;
  late final Computed<bool> _isAuthenticated;

  BloomAuth({
    this.storage,
    U Function(Map<String, dynamic> json)? fromJson,
    U Function(Map<String, dynamic> json)? userDeserializer,
    Map<String, dynamic> Function(U user)? toJson,
    Map<String, dynamic> Function(U user)? userSerializer,
    this.sessionKey = 'bloom_auth_session',
    bool autoProvide = false,
  })  : fromJson = fromJson ?? userDeserializer,
        toJson = toJson ?? userSerializer {
    _currentUser = signal<U?>(null, debugLabel: 'auth.currentUser');
    _token = signal<String?>(null, debugLabel: 'auth.token');
    _isAuthenticated = computed<bool>(
      () => _currentUser.value != null && _token.value != null && _token.value!.isNotEmpty,
      debugLabel: 'auth.isAuthenticated',
    );

    if (autoProvide) {
      globalContainer.provideValue<BloomAuthBase>(this);
    }
  }

  ReadonlySignal<U?> get currentUser => _currentUser.readonly();
  @override
  ReadonlySignal<String?> get token => _token.readonly();
  @override
  ReadonlySignal<bool> get isAuthenticated => _isAuthenticated.readonly();

  /// Set the active user session and optionally persist it to secure storage.
  Future<void> setSession({required U user, required String token}) async {
    _currentUser.value = user;
    _token.value = token;

    if (storage != null && toJson != null) {
      final sessionData = {
        'user': toJson!(user),
        'token': token,
      };
      await storage!.write(sessionKey, jsonEncode(sessionData));
    }
    logger.info('BloomAuth: User session established.');
  }

  /// Login user setting active session (supports positional `login(token, user)`).
  Future<void> login(String token, U user) =>
      setSession(user: user, token: token);

  /// Restore user session from persistent storage (e.g. on application boot).
  Future<bool> restoreSession() async {
    if (storage == null || fromJson == null) return false;

    try {
      final raw = await storage!.read(sessionKey);
      if (raw == null || raw.isEmpty) return false;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final tokenStr = decoded['token'] as String?;
      final userData = decoded['user'] as Map<String, dynamic>?;

      if (tokenStr != null && userData != null) {
        _token.value = tokenStr;
        _currentUser.value = fromJson!(userData);
        logger.info('BloomAuth: Restored session from storage (hasUser: ${_currentUser.value != null})');
        return true;
      }
    } catch (e) {
      logger.error('BloomAuth: Failed to restore session from storage: $e');
    }
    return false;
  }

  /// Clear the active user session and purge persistent session storage.
  @override
  Future<void> logout() async {
    _currentUser.value = null;
    _token.value = null;

    if (storage != null) {
      await storage!.delete(sessionKey);
    }
    logger.info('BloomAuth: User logged out.');
  }
}

/// Standard authentication route guard protecting authenticated screens.
class BloomAuthGuard implements BloomGuard {
  final String loginPath;
  final BloomAuthBase? auth;

  const BloomAuthGuard({
    this.loginPath = '/login',
    this.auth,
  });

  @override
  FutureOr<GuardResult> canActivate(BuildContext context, BloomRouteMatch match) {
    final activeAuth = auth ?? injectOrNull<BloomAuthBase>();

    if (activeAuth == null || !activeAuth.isAuthenticated.value) {
      final currentUri = Uri.encodeComponent(match.location);
      final redirect = '$loginPath?from=$currentUri';
      return GuardResult.redirect(redirect);
    }

    return GuardResult.allow();
  }
}
