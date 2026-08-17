// lib/src/permissions.dart
import 'dart:async';
import 'package:bloom_framework/bloom_server.dart';

/// A policy deciding whether an incoming [BloomRequest] may reach a ViewSet handler.
///
/// Mirrors `djangors_rest::Permission`.
abstract class BloomRestPermission {
  const BloomRestPermission();

  /// Determines whether the given request satisfies this permission requirement.
  FutureOr<bool> hasPermission(BloomRequest req);
}

/// Composable combinator extension methods for [BloomRestPermission].
///
/// Enables chaining: `IsAuthenticated().and(IsStaff()).or(IsReadOnly())`.
extension BloomPermissionExt on BloomRestPermission {
  /// Requires both this policy and [other].
  BloomRestPermission and(BloomRestPermission other) => BloomAndPermission(this, other);

  /// Requires either this policy or [other].
  BloomRestPermission or(BloomRestPermission other) => BloomOrPermission(this, other);

  /// Inverts this policy requirement.
  BloomRestPermission negate() => BloomNotPermission(this);

  /// Operator `&` alias for [and].
  BloomRestPermission operator &(BloomRestPermission other) => and(other);

  /// Operator `|` alias for [or].
  BloomRestPermission operator |(BloomRestPermission other) => or(other);

  /// Operator `~` alias for [negate].
  BloomRestPermission operator ~() => negate();
}

/// Combinator requiring both policies (A AND B).
class BloomAndPermission extends BloomRestPermission {
  final BloomRestPermission a;
  final BloomRestPermission b;

  const BloomAndPermission(this.a, this.b);

  @override
  Future<bool> hasPermission(BloomRequest req) async {
    final resA = await a.hasPermission(req);
    if (!resA) return false;
    return await b.hasPermission(req);
  }
}

/// Combinator requiring either policy (A OR B).
class BloomOrPermission extends BloomRestPermission {
  final BloomRestPermission a;
  final BloomRestPermission b;

  const BloomOrPermission(this.a, this.b);

  @override
  Future<bool> hasPermission(BloomRequest req) async {
    final resA = await a.hasPermission(req);
    if (resA) return true;
    return await b.hasPermission(req);
  }
}

/// Combinator inverting a policy (NOT P).
class BloomNotPermission extends BloomRestPermission {
  final BloomRestPermission inner;

  const BloomNotPermission(this.inner);

  @override
  Future<bool> hasPermission(BloomRequest req) async {
    final res = await inner.hasPermission(req);
    return !res;
  }
}

/// Resolves the authenticated user ID for a request.
/// Checks `request.params['auth_user_id']` or `Authorization` Bearer token header.
///
/// Only reads `req.params['auth_user_id']` — a value exclusively populated by
/// verified server-side auth middleware (e.g. `bloom_auth_server`'s
/// `BloomAuthMiddleware`) after cryptographic signature verification. This
/// deliberately does NOT fall back to reading the raw `Authorization` header
/// itself: an unverified bearer token string is not proof of identity, and
/// treating it as one would let any caller authenticate as any user simply by
/// presenting an arbitrary token. Callers relying on [BloomRestPermission]s
/// like [IsAuthenticated] MUST wire real auth-verification middleware ahead of
/// the route in the middleware chain — permission checks here only consume an
/// already-verified identity, they never verify one themselves.
String? resolveCurrentUserId(BloomRequest req) {
  final paramId = req.params['auth_user_id'];
  if (paramId != null && paramId.isNotEmpty) {
    return paramId;
  }
  return null;
}

/// Returns the verified roles attached by trusted auth middleware, or an
/// empty list if unauthenticated. See [resolveCurrentUserId] for why this
/// only reads `req.params['auth_roles']` and never raw client headers.
List<String> resolveCurrentUserRoles(BloomRequest req) {
  final raw = req.params['auth_roles'];
  if (raw == null || raw.isEmpty) return const [];
  return raw.split(',').where((r) => r.isNotEmpty).toList();
}

/// Explicitly permits unauthenticated and public requests.
///
/// Mirrors `djangors_rest::AllowAny`.
class AllowAny extends BloomRestPermission {
  const AllowAny();

  @override
  bool hasPermission(BloomRequest req) => true;
}

/// Requires a valid authenticated session, user token, or header context.
///
/// Mirrors `djangors_rest::IsAuthenticated`.
class IsAuthenticated extends BloomRestPermission {
  const IsAuthenticated();

  @override
  bool hasPermission(BloomRequest req) {
    final userId = resolveCurrentUserId(req);
    return userId != null && userId.isNotEmpty;
  }
}

/// Requires an authenticated user flagged as staff / admin.
///
/// Mirrors `djangors_rest::IsStaff`.
class IsStaff extends BloomRestPermission {
  final String roleName;

  const IsStaff({this.roleName = 'staff'});

  @override
  bool hasPermission(BloomRequest req) {
    final roles = resolveCurrentUserRoles(req);
    return roles.contains(roleName) || roles.contains('admin') || roles.contains('superuser');
  }
}

/// Requires an authenticated superuser / admin.
///
/// Mirrors `djangors_rest::IsSuperuser`.
class IsSuperuser extends BloomRestPermission {
  const IsSuperuser();

  @override
  bool hasPermission(BloomRequest req) {
    final roles = resolveCurrentUserRoles(req);
    return roles.contains('admin') || roles.contains('superuser');
  }
}

/// Permits only non-mutating safe HTTP methods (GET, HEAD, OPTIONS).
///
/// On its own makes an endpoint read-only for everyone.
/// Combined with another policy: `IsReadOnly().or(IsStaff())`.
///
/// Mirrors `djangors_rest::IsReadOnly`.
class IsReadOnly extends BloomRestPermission {
  const IsReadOnly();

  @override
  bool hasPermission(BloomRequest req) {
    final m = req.method.toUpperCase();
    return m == 'GET' || m == 'HEAD' || m == 'OPTIONS';
  }
}
