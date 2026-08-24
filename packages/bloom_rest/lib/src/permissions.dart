// lib/src/permissions.dart
import 'dart:async';
import 'package:bloom_server/bloom_server.dart';

/// A policy deciding whether an incoming [BloomRequest] may reach a ViewSet handler.
///
/// Implement this class to enforce authorization rules on ViewSet endpoints. Permissions
/// can be combined using [and], [or], [negate] (or their operator equivalents `&`, `|`, `~`).
///
/// Example:
/// ```dart
/// class HasOrgMembership extends BloomRestPermission {
///   final String orgId;
///   const HasOrgMembership(this.orgId);
///
///   @override
///   bool hasPermission(BloomRequest req) {
///     final userOrgs = req.params['auth_orgs']?.split(',') ?? [];
///     return userOrgs.contains(orgId);
///   }
/// }
/// ```
///
/// Mirrors `djangors_rest::Permission`.
abstract class BloomRestPermission {
  /// Creates a [BloomRestPermission] instance.
  const BloomRestPermission();

  /// Determines whether the given [req] satisfies this permission requirement.
  ///
  /// Returns `true` if access is granted, or `false` to deny access (yielding a 401 Unauthorized response).
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
///
/// Returns `true` only if both [a] and [b] grant permission.
class BloomAndPermission extends BloomRestPermission {
  /// First permission requirement.
  final BloomRestPermission a;

  /// Second permission requirement.
  final BloomRestPermission b;

  /// Creates an AND combinator requiring both [a] and [b] to succeed.
  const BloomAndPermission(this.a, this.b);

  @override
  Future<bool> hasPermission(BloomRequest req) async {
    final resA = await a.hasPermission(req);
    if (!resA) return false;
    return await b.hasPermission(req);
  }
}

/// Combinator requiring either policy (A OR B).
///
/// Returns `true` if either [a] or [b] grants permission.
class BloomOrPermission extends BloomRestPermission {
  /// First permission requirement.
  final BloomRestPermission a;

  /// Second permission requirement.
  final BloomRestPermission b;

  /// Creates an OR combinator requiring either [a] or [b] to succeed.
  const BloomOrPermission(this.a, this.b);

  @override
  Future<bool> hasPermission(BloomRequest req) async {
    final resA = await a.hasPermission(req);
    if (resA) return true;
    return await b.hasPermission(req);
  }
}

/// Combinator inverting a policy (NOT P).
///
/// Returns `true` if [inner] denies permission, and `false` if [inner] grants permission.
class BloomNotPermission extends BloomRestPermission {
  /// Inner permission requirement to invert.
  final BloomRestPermission inner;

  /// Creates a NOT combinator inverting [inner].
  const BloomNotPermission(this.inner);

  @override
  Future<bool> hasPermission(BloomRequest req) async {
    final res = await inner.hasPermission(req);
    return !res;
  }
}

/// Resolves the authenticated user ID for a request.
/// Checks `request.params['auth_user_id']`.
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
///
/// Returns the verified user ID string, or `null` if unauthenticated.
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
/// Always evaluates to `true`. Use this when configuring public ViewSets since ViewSets
/// default to [IsAuthenticated].
///
/// Example:
/// ```dart
/// final options = BloomViewSetOptions<Article>(
///   serializer: serializer,
///   permission: const AllowAny(),
/// );
/// ```
///
/// Mirrors `djangors_rest::AllowAny`.
class AllowAny extends BloomRestPermission {
  /// Creates an [AllowAny] permission granting access to all requests.
  const AllowAny();

  @override
  bool hasPermission(BloomRequest req) => true;
}

/// Requires a valid authenticated session or user token context.
///
/// Checks whether [resolveCurrentUserId] returns a valid non-empty user ID populated
/// by verified auth middleware.
///
/// Example:
/// ```dart
/// final permission = const IsAuthenticated();
/// ```
///
/// Mirrors `djangors_rest::IsAuthenticated`.
class IsAuthenticated extends BloomRestPermission {
  /// Creates an [IsAuthenticated] permission.
  const IsAuthenticated();

  @override
  bool hasPermission(BloomRequest req) {
    final userId = resolveCurrentUserId(req);
    return userId != null && userId.isNotEmpty;
  }
}

/// Requires an authenticated user flagged as staff or admin.
///
/// Validates that the user has [roleName] (defaults to `'staff'`), `'admin'`, or `'superuser'`.
///
/// Example:
/// ```dart
/// final permission = const IsStaff();
/// ```
///
/// Mirrors `djangors_rest::IsStaff`.
class IsStaff extends BloomRestPermission {
  /// Role name required for staff access (defaults to `'staff'`).
  final String roleName;

  /// Creates an [IsStaff] permission requiring [roleName], `'admin'`, or `'superuser'`.
  const IsStaff({this.roleName = 'staff'});

  @override
  bool hasPermission(BloomRequest req) {
    final roles = resolveCurrentUserRoles(req);
    return roles.contains(roleName) || roles.contains('admin') || roles.contains('superuser');
  }
}

/// Requires an authenticated superuser / admin.
///
/// Validates that the user has either the `'admin'` or `'superuser'` role.
///
/// Example:
/// ```dart
/// final permission = const IsSuperuser();
/// ```
///
/// Mirrors `djangors_rest::IsSuperuser`.
class IsSuperuser extends BloomRestPermission {
  /// Creates an [IsSuperuser] permission requiring `'admin'` or `'superuser'` roles.
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
/// Example:
/// ```dart
/// final readOrAuth = const IsReadOnly().or(const IsAuthenticated());
/// ```
///
/// Mirrors `djangors_rest::IsReadOnly`.
class IsReadOnly extends BloomRestPermission {
  /// Creates an [IsReadOnly] permission permitting only safe HTTP methods (GET, HEAD, OPTIONS).
  const IsReadOnly();

  @override
  bool hasPermission(BloomRequest req) {
    final m = req.method.toUpperCase();
    return m == 'GET' || m == 'HEAD' || m == 'OPTIONS';
  }
}

