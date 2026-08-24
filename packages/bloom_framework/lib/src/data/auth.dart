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
///
/// Exposes reactive authentication status signals and session termination.
///
/// Example:
/// ```dart
/// final auth = inject<BloomAuthBase>();
/// print('Authenticated: ${auth.isAuthenticated.value}');
/// ```
abstract class BloomAuthBase {
  /// Reactive boolean signal indicating whether an active authenticated session exists.
  ReadonlySignal<bool> get isAuthenticated;

  /// Reactive signal containing the current authentication bearer token, or `null` if unauthenticated.
  ReadonlySignal<String?> get token;

  /// Clears the active session and logs the current user out.
  Future<void> logout();
}

/// Reactive user session manager and persistent authentication layer.
///
/// Tracks current user [U] model, bearer [token], and provides computed reactive
/// authentication state signals. Supports optional encrypted persistence via [BloomStorageAdapter].
///
/// Example:
/// ```dart
/// final auth = BloomAuth<User>(
///   storage: BloomSecureStorage(),
///   fromJson: User.fromJson,
///   toJson: (u) => u.toJson(),
/// );
///
/// await auth.setSession(user: currentUser, token: 'jwt_token');
/// print(auth.isAuthenticated.value); // true
/// ```
class BloomAuth<U> implements BloomAuthBase {
  /// Optional persistent storage adapter for caching session state across application restarts.
  final BloomStorageAdapter? storage;

  /// Deserializer function converting JSON maps to typed user model instances.
  final U Function(Map<String, dynamic> json)? fromJson;

  /// Serializer function converting typed user model instances to JSON maps.
  final Map<String, dynamic> Function(U user)? toJson;

  /// Key identifier used when writing session data into [storage] (defaults to `'bloom_auth_session'`).
  final String sessionKey;

  late final Signal<U?> _currentUser;
  late final Signal<String?> _token;
  late final Computed<bool> _isAuthenticated;

  /// Creates a [BloomAuth] session manager.
  ///
  /// If [autoProvide] is true, registers this instance into the global DI container.
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

  /// Reactive signal containing the currently authenticated user model, or `null` if unauthenticated.
  ReadonlySignal<U?> get currentUser => _currentUser.readonly();

  /// Reactive signal containing the current authentication bearer token, or `null` if unauthenticated.
  @override
  ReadonlySignal<String?> get token => _token.readonly();

  /// Reactive boolean signal indicating whether an active authenticated session exists.
  @override
  ReadonlySignal<bool> get isAuthenticated => _isAuthenticated.readonly();

  /// Sets the active user [user] and [token] session, and persists it to [storage] if configured.
  ///
  /// Example:
  /// ```dart
  /// await auth.setSession(user: loggedInUser, token: 'access_token');
  /// ```
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

  /// Logs in the user, setting the active [token] and [user] session.
  ///
  /// Positional convenience alias for [setSession].
  ///
  /// Example:
  /// ```dart
  /// await auth.login('access_token', loggedInUser);
  /// ```
  Future<void> login(String token, U user) =>
      setSession(user: user, token: token);

  /// Restores user session from persistent [storage] on application startup.
  ///
  /// Returns `true` if a valid persisted session was found and restored.
  ///
  /// Example:
  /// ```dart
  /// final hasSession = await auth.restoreSession();
  /// ```
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

  /// Clears the active user session and purges persistent session storage.
  ///
  /// Example:
  /// ```dart
  /// await auth.logout();
  /// ```
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
///
/// Redirects unauthenticated visitors to [loginPath] (preserving original route in `?from=...` query).
///
/// Example:
/// ```dart
/// BloomRoute(
///   path: '/dashboard',
///   guards: const [BloomAuthGuard()],
///   builder: (context, match) => const DashboardScreen(),
/// );
/// ```
class BloomAuthGuard implements BloomGuard {
  /// Path to redirect unauthenticated users to (defaults to `'/login'`).
  final String loginPath;

  /// Explicit [BloomAuthBase] session manager override. If null, resolved via global DI.
  final BloomAuthBase? auth;

  /// Creates a [BloomAuthGuard] with an optional [loginPath] and [auth] manager override.
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
