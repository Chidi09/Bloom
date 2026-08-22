import 'package:bloom_auth_server/bloom_auth_server.dart';

/// Re-exports bloom_rest's built-in permission classes (IsAuthenticated,
/// IsStaff, IsSuperuser, AllowAny, IsReadOnly) for local use by views.dart,
/// mirroring Django's `permissions.py` convention. This app has no custom
/// permission classes of its own — bloom_rest's built-ins cover every route.
export 'package:bloom_rest/bloom_rest.dart' show BloomRestPermission, IsAuthenticated, IsStaff, IsSuperuser, AllowAny, IsReadOnly, BloomPermissionExt;

/// Rate limiter for the login endpoint: 5 attempts per 15min window,
/// 1 hour lockout on repeated failures.
final authLimiter = AuthRateLimiter(
  maxAttempts: 5,
  window: const Duration(minutes: 15),
  lockoutDuration: const Duration(hours: 1),
);
