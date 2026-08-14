// lib/src/data/auth.dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import '../core/logger.dart';
import '../di/container.dart';
import '../router/route.dart';
import '../state/signals.dart';
import 'storage.dart';

/// Central authentication and session manager for Bloom applications.
class BloomAuth<U> {
  final BloomStorageAdapter storage;
  final String storageKeyToken;
  final String storageKeyUser;
  final U Function(Map<String, dynamic> json)? userDeserializer;
  final Map<String, dynamic> Function(U user)? userSerializer;

  late final Signal<U?> _currentUser;
  late final Signal<String?> _token;
  late final Computed<bool> _isAuthenticated;

  BloomAuth({
    BloomStorageAdapter? storage,
    this.storageKeyToken = 'bloom_auth_token',
    this.storageKeyUser = 'bloom_auth_user',
    this.userDeserializer,
    this.userSerializer,
  }) : storage = storage ?? InMemoryStorageAdapter() {
    _currentUser = signal<U?>(null, debugLabel: 'auth.user');
    _token = signal<String?>(null, debugLabel: 'auth.token');
    _isAuthenticated = computed(() => _token.value != null && _currentUser.value != null, debugLabel: 'auth.isAuthenticated');
  }

  ReadonlySignal<U?> get currentUser => _currentUser.readonly();
  ReadonlySignal<String?> get token => _token.readonly();
  ReadonlySignal<bool> get isAuthenticated => _isAuthenticated.readonly();

  /// Log in a user with a token and user model, persisting session if storage is available.
  Future<void> login(String authToken, U user) async {
    _token.value = authToken;
    _currentUser.value = user;

    await storage.write(storageKeyToken, authToken);
    if (userSerializer != null) {
      final userJson = userSerializer!(user);
      await BloomJsonStorage(storage).writeJson(storageKeyUser, userJson);
    }
    logger.info('BloomAuth: User session established.');
  }

  /// Clear the current session and remove stored credentials.
  Future<void> logout() async {
    _token.value = null;
    _currentUser.value = null;
    await storage.delete(storageKeyToken);
    await storage.delete(storageKeyUser);
    logger.info('BloomAuth: User logged out.');
  }

  /// Restore user session from persistent storage during app boot.
  Future<bool> restoreSession() async {
    final savedToken = await storage.read(storageKeyToken);
    if (savedToken == null || savedToken.isEmpty) return false;

    U? restoredUser;
    if (userDeserializer != null) {
      final userDoc = await BloomJsonStorage(storage).readJson(storageKeyUser);
      if (userDoc != null) {
        try {
          restoredUser = userDeserializer!(userDoc);
        } catch (e) {
          logger.warn('Failed to deserialize saved user: $e');
        }
      }
    }

    _token.value = savedToken;
    _currentUser.value = restoredUser;
    logger.info('BloomAuth: Restored session from storage (hasUser: ${restoredUser != null})');
    return true;
  }
}

/// Standard route guard enforcing authentication on protected routes.
class BloomAuthGuard extends BloomGuard {
  final String loginPath;
  const BloomAuthGuard({this.loginPath = '/login'});

  @override
  FutureOr<GuardResult> canActivate(BuildContext context, BloomRouteMatch match) {
    final auth = globalContainer.injectOrNull<BloomAuth>();
    if (auth != null && auth.isAuthenticated.value) {
      return GuardResult.allow();
    }
    return GuardResult.redirect('$loginPath?from=${Uri.encodeComponent(match.location)}');
  }
}
