## 0.3.1 - 2026-08-25

### Fixed
* Bumped `bloom_server` dependency constraint from `^0.1.0` to `^0.2.0` — the stale constraint was incompatible with any sibling package (`bloom_cache`, `bloom_i18n`) requiring `bloom_server ^0.2.0`, breaking `pub get` in any app combining them.

## 0.3.0 - 2026-08-25

### Added
* **OAuth2 / social login.** New `BloomOAuthProvider` interface with real Google and GitHub Authorization Code flow implementations (`GoogleOAuthProvider`, `GitHubOAuthProvider`) — authorization URL construction, code exchange, and profile fetch (GitHub's primary-verified-email lookup included). `BloomOAuthFlow` ties a provider to the existing JWT session-token issuance via an app-supplied `resolveUser` callback, and includes a CSRF-safe `state` generator. Closes the previous local-password-only auth gap.

## 0.2.0 - 2026-08-23

### Breaking
- Now depends on `bloom_server` instead of `bloom_framework`. Imports change from
  `package:bloom_framework/bloom_server.dart` to `package:bloom_server/bloom_server.dart`.
- **No longer requires Flutter.** The package now resolves against the Flutter-free
  `bloom_server` core, so it can be used from a plain `dart run`/`dart compile` backend.

## 0.1.0

- Initial release of `bloom_auth_server`.
- **Password Hashing & Verification**: Strong, constant-time BCrypt hashing (`hashPassword`, `verifyPassword`, `dummyVerifyPassword`) with configurable cost factor and user-enumeration defense.
- **Session & Bearer Token Issuance**: Cryptographically signed Bearer JWT issuance (`issueSessionToken`, `verifySessionToken`) bound with expiration, user identity, and custom claims.
- **Sliding-Window Rate Limiting & Account Lockout**: In-memory rate limiting (`InMemoryRateLimiter`) and persistent-style lockout tracker (`InMemoryLockoutManager`, `AuthRateLimiter`) with fail-closed security semantics.
- **Password Reset Workflows**: Single-purpose, time-limited, HMAC-signed password reset tokens (`generatePasswordResetToken`, `verifyPasswordResetToken`) cryptographically bound to the user's current password hash to ensure instant invalidation upon password modification.
- **Bloom Server Middleware**: Drop-in `BloomAuthMiddleware` for `BloomApiRouter` supporting Bearer token extraction, claim hydration, role validation, and `BloomRequest` context extensions (`request.auth`, `request.authUserId`, `request.isAuthenticated`).
